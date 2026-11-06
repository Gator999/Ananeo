#!/usr/bin/env python3
"""Creates the App Review demo accounts and their content on the HOSTED Supabase project.

Run from the iOS project folder after `supabase link`:

    python3 scripts/seed-review.py

What it does, in order:
  1. Writes fresh passwords to Config/ReviewAccount.md (gitignored). Put the reviewer's into
     App Store Connect > App Review Information.
  2. Runs one SQL batch through `supabase db query --linked`: three email/password accounts pinned to
     Cupertino via app_metadata.demo_location, listings, requests, a reserved pickup, two finished
     handoffs, chats, one open report, a moderator row for the reviewer, and five unverified places.
     Everything has fixed ids and is deleted first, so re-running resets the demo.
  3. Draws a placeholder photo per listing (Pillow) and uploads it, with its thumbnail, as each owner
     through the storage API, using the publishable key from Config/Secrets.xcconfig.

With --photos-only it skips steps 1 and 2, reads the passwords already in Config/ReviewAccount.md,
and only draws and uploads the photos (for when the SQL was run by hand in the dashboard). The
listings then need their photo paths set; the script prints the SQL for that.

Nothing here touches real accounts. The demo location only affects accounts whose app_metadata has it.
"""
import json
import pathlib
import re
import secrets
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
R, M, J = '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', '33333333-3333-4333-8333-333333333333'
DEMO_LOCATION = '{"latitude": 37.3230, "longitude": -122.0322}'  # Cupertino


def password(prefix):
    return f"{prefix}-{secrets.token_hex(4)}-{secrets.token_hex(4)}"


USERS = [  # id, email, display name, password
    (R, 'appreview@ananeo.app', 'App Reviewer', password('Review')),
    (M, 'maya.demo@ananeo.app', 'Maya R.', password('Demo')),
    (J, 'jordan.demo@ananeo.app', 'Jordan K.', password('Demo')),
]

# slug, owner, title, details, category, condition, mode, wants, lat, lng, status, emoji, top color, bottom color
ITEMS = [
    ('bookshelf', M, 'Solid oak bookshelf', 'Five shelves, 72 inches tall. Heavy, so bring a second person. Pickup from the garage any evening.', 'furniture', 'good', 'give', None, 37.3180, -122.0400, 'available', '🗄️', (214, 196, 170), (160, 128, 92)),
    ('kids_bike', M, "Kids' bike, 16-inch", 'Outgrown. Tires hold air and the brakes work. A few scratches on the frame.', 'other', 'worn', 'give', None, 37.3290, -122.0250, 'available', '🚲', (198, 226, 240), (110, 160, 200)),
    ('coats', M, 'Winter coats, bundle of 3', "Two adult mediums and one kids' large. Clean, zippers all work.", 'clothing', 'good', 'give', None, 37.3120, -122.0280, 'available', '🧥', (226, 214, 232), (150, 120, 170)),
    ('mixer', M, 'Stand mixer, missing the beater', 'Motor runs fine, but the flat beater is gone and the bowl has a dent. Good for parts or a project.', 'household', 'needs_repair', 'parts', None, 37.3350, -122.0450, 'available', '🥣', (240, 226, 200), (210, 160, 100)),
    ('toaster', M, 'Toaster oven', 'Works great, just upgraded. Comes with the tray.', 'household', 'good', 'give', None, 37.3200, -122.0300, 'handed_off', '🍞', (244, 226, 210), (200, 130, 90)),
    ('novels', J, 'Box of paperback novels', 'About 30 mysteries and thrillers, read once. Take the whole box.', 'books', 'like_new', 'give', None, 37.3400, -122.0200, 'available', '📚', (220, 232, 210), (120, 160, 110)),
    ('drill', J, 'Cordless drill with charger', '18V, two batteries, both hold a charge. Looking to swap.', 'tools', 'good', 'swap', 'a hand saw or a level', 37.3080, -122.0350, 'available', '🔧', (226, 226, 226), (120, 130, 140)),
    ('monitor', J, '27-inch monitor', '1440p, HDMI and DisplayPort. No dead pixels. Stand included.', 'electronics', 'good', 'give', None, 37.3260, -122.0120, 'available', '🖥️', (210, 220, 236), (90, 110, 150)),
    ('cedar', J, 'Scrap cedar boards', 'Offcuts from a fence project, 2 to 4 feet long. Great for planters.', 'materials', 'worn', 'give', None, 37.3450, -122.0350, 'available', '🪵', (236, 220, 196), (170, 120, 80)),
    ('road_bike', J, 'Road bike, 56 cm', 'Aluminum frame, needs new bar tape. Shifts clean.', 'other', 'good', 'give', None, 37.3300, -122.0400, 'reserved', '🚴', (210, 236, 226), (60, 150, 120)),
    ('lamp', R, 'Floor lamp, brass', 'Arc floor lamp, about 6 feet. Takes a standard bulb, one included.', 'household', 'good', 'give', None, 37.3230, -122.0322, 'available', '💡', (250, 240, 200), (230, 190, 90)),
    ('desk_chair', R, 'Desk chair', 'Mesh back, adjustable height. One armrest is a little loose.', 'furniture', 'good', 'give', None, 37.3230, -122.0322, 'handed_off', '🪑', (220, 228, 224), (110, 150, 130)),
]

PLACES = [
    ('donation', 'Cupertino Donation Center', '10100 N De Anza Blvd', 37.3240, -122.0330, '{clothing,books,household,furniture}', 'Mon–Sat 9–6'),
    ('donation', 'Westside ReStore', '21000 Stevens Creek Blvd', 37.3235, -122.0650, '{furniture,tools,household,materials}', 'Wed–Sun 10–5'),
    ('repair', 'Fix-It Saturday', '10800 Torre Ave, Community Hall', 37.3185, -122.0300, '{electronics,tools,household}', 'Second Saturday, 12–4'),
    ('ewaste', 'E-Waste Drop-Off', '10300 Ainsworth Dr', 37.3390, -122.0550, '{electronics}', 'Tue–Sat 9–4'),
    ('textile', 'Textile Recycling Bin', 'Stevens Creek Blvd & Wolfe Rd', 37.3238, -122.0150, '{clothing}', 'Always open'),
]


def uid(n):
    return f'{n:08x}-0000-4000-8000-{n:012x}'


def q(text):
    return "'" + text.replace("'", "''") + "'"


ITEM_ID = {slug: uid(100 + i) for i, (slug, *_) in enumerate(ITEMS)}


def build_sql():
    sql = ["-- Demo content for App Review. Re-runnable: fixed ids, deleted first."]
    sql.append(f"delete from auth.users where id in ('{R}', '{M}', '{J}');")
    sql.append("delete from public.places where id in (" + ", ".join(f"'{uid(900 + i)}'" for i in range(len(PLACES))) + ");")
    for i, (id_, email, name, pw) in enumerate(USERS):
        meta = f'{{"provider": "email", "providers": ["email"], "demo_location": {DEMO_LOCATION}}}'
        sql.append(
            "insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current, phone_change, phone_change_token, reauthentication_token, is_sso_user, is_anonymous)\n"
            f"values ('00000000-0000-0000-0000-000000000000', '{id_}', 'authenticated', 'authenticated', {q(email)}, extensions.crypt({q(pw)}, extensions.gen_salt('bf')), now(), '{meta}'::jsonb, '{{\"full_name\": {json.dumps(name)}}}'::jsonb, now() - interval '{30 - i * 3} days', now(), '', '', '', '', '', '', '', '', false, false);"
        )
        sql.append(
            "insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)\n"
            f"values (gen_random_uuid(), '{id_}', '{id_}', 'email', '{{\"sub\": \"{id_}\", \"email\": {json.dumps(email)}, \"email_verified\": true, \"phone_verified\": false}}'::jsonb, now(), now(), now());"
        )
        sql.append(f"update public.profiles set created_at = now() - interval '{30 - i * 3} days' where id = '{id_}';")
    sql.append(f"insert into public.moderators (user_id) values ('{R}') on conflict do nothing;")

    # The before-write trigger fuzzes each point and fills est_kg from the category.
    for i, (slug, owner, title, details, cat, cond, mode, wants, lat, lng, status, *_) in enumerate(ITEMS):
        sql.append(
            "insert into public.items (id, owner_id, title, details, category, condition, mode, status, wants, location, photos, created_at)\n"
            f"values ('{ITEM_ID[slug]}', '{owner}', {q(title)}, {q(details)}, '{cat}', '{cond}', '{mode}', '{status}', {q(wants) if wants else 'null'}, 'SRID=4326;POINT({lng} {lat})', '{{{owner}/{slug}.jpg}}', now() - interval '{(len(ITEMS) - i) * 7 + 3} hours');"
        )

    convs = {  # conversation = pickup request
        'lamp_maya': (uid(201), ITEM_ID['lamp'], R, M, '2 hours'),
        'lamp_jordan': (uid(202), ITEM_ID['lamp'], R, J, '40 minutes'),
        'bike': (uid(203), ITEM_ID['road_bike'], J, R, '1 day'),
        'monitor': (uid(204), ITEM_ID['monitor'], J, R, '5 hours'),
        'toaster': (uid(205), ITEM_ID['toaster'], M, R, '4 days'),
        'chair': (uid(206), ITEM_ID['desk_chair'], R, M, '7 days'),
    }
    for cid, item, giver, receiver, ago in convs.values():
        sql.append(f"insert into public.conversations (id, item_id, giver_id, receiver_id, created_at) values ('{cid}', '{item}', '{giver}', '{receiver}', now() - interval '{ago}');")

    messages = [
        ('lamp_maya', M, "Hi! Is the lamp still available? I could pick it up tomorrow after 5.", '2 hours'),
        ('lamp_jordan', J, "Would love this for my reading corner. Any time this weekend works for me.", '40 minutes'),
        ('bike', R, "Hi Jordan, I'd love the bike if it's still free.", '1 day'),
        ('bike', J, "It's yours! I reserved it for you.", '23 hours'),
        ('bike', J, "It's on the porch by the side gate whenever you're ready.", '3 hours'),
        ('monitor', R, "Is the monitor still available?", '5 hours'),
        ('toaster', R, "Picked it up, thanks so much. Works great!", '3 days'),
        ('toaster', M, "So glad it found a home!", '3 days'),
        ('chair', M, "Got the chair, thank you!!", '6 days'),
    ]
    for i, (c, sender, body, ago) in enumerate(messages):
        sql.append(f"insert into public.messages (id, conversation_id, sender_id, body, created_at) values ('{uid(300 + i)}', '{convs[c][0]}', '{sender}', {q(body)}, now() - interval '{ago}');")

    # Getting: the bike is reserved for the reviewer and Jordan has confirmed. Done: one given, one received.
    sql.append(f"insert into public.handoffs (id, item_id, giver_id, receiver_id, confirmed_by_giver, confirmed_by_receiver, est_kg, created_at) values ('{uid(401)}', '{ITEM_ID['road_bike']}', '{J}', '{R}', true, false, 10, now() - interval '23 hours');")
    sql.append(f"insert into public.handoffs (id, item_id, giver_id, receiver_id, confirmed_by_giver, confirmed_by_receiver, est_kg, created_at, completed_at) values ('{uid(402)}', '{ITEM_ID['toaster']}', '{M}', '{R}', true, true, 1.5, now() - interval '4 days', now() - interval '3 days');")
    sql.append(f"insert into public.handoffs (id, item_id, giver_id, receiver_id, confirmed_by_giver, confirmed_by_receiver, est_kg, created_at, completed_at) values ('{uid(403)}', '{ITEM_ID['desk_chair']}', '{R}', '{M}', true, true, 25, now() - interval '7 days', now() - interval '6 days');")
    # Read state: both lamp requests and Jordan's latest bike message stay unread, so the tab badge shows.
    sql.append(
        "insert into public.conversation_reads (conversation_id, user_id, read_at) values "
        f"('{convs['toaster'][0]}', '{R}', now() - interval '3 days'), ('{convs['chair'][0]}', '{R}', now() - interval '6 days'), "
        f"('{convs['bike'][0]}', '{R}', now() - interval '20 hours'), ('{convs['monitor'][0]}', '{R}', now() - interval '5 hours');"
    )
    sql.append(f"insert into public.reports (reporter_id, target_type, target_id, reason, created_at) values ('{M}', 'item', '{ITEM_ID['cedar']}', 'Spam or scam: Looks like a business selling lumber, not a neighbor.', now() - interval '8 hours');")
    for i, (kind, name, addr, lat, lng, accepts, hours) in enumerate(PLACES):
        sql.append(f"insert into public.places (id, kind, name, address, location, accepts, hours, verified) values ('{uid(900 + i)}', '{kind}', {q(name)}, {q(addr)}, 'SRID=4326;POINT({lng} {lat})', '{accepts}', {q(hours)}, false);")
    return "\n".join(sql) + "\n"


def write_credentials():
    rows = "\n".join(f"| {role} | {email} | {pw} |" for role, (_, email, _, pw) in zip(['Reviewer (moderator)', 'Neighbor, giver side', 'Neighbor, other side'], USERS))
    (ROOT / 'Config' / 'ReviewAccount.md').write_text(
        "# App Review demo account (gitignored)\n\n"
        "Created by scripts/seed-review.py on the hosted project. All three accounts are pinned to Cupertino\n"
        "(app_metadata.demo_location), so their content shows wherever the reviewer is.\n\n"
        "| Role | Email | Password |\n|---|---|---|\n" + rows + "\n\n"
        "Sign in: Welcome screen > \"Sign in with email\". Re-run the script to reset the content (new passwords).\n"
    )


def run_sql(sql):
    with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False) as f:
        f.write(sql)
    out = subprocess.run(['supabase', 'db', 'query', '--linked', '-f', f.name], cwd=ROOT, capture_output=True, text=True)
    pathlib.Path(f.name).unlink()
    if out.returncode != 0:
        sys.exit(f"SQL failed:\n{out.stdout}\n{out.stderr}")


def backend():
    text = (ROOT / 'Config' / 'Secrets.xcconfig').read_text()
    url = re.search(r'SUPABASE_URL\s*=\s*(\S+)', text).group(1).replace('$()', '')
    key = re.search(r'SUPABASE_KEY\s*=\s*(\S+)', text).group(1)
    return url, key


def draw_photos(folder):
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
    emoji_font = ImageFont.truetype('/System/Library/Fonts/Apple Color Emoji.ttc', 160)
    W, H = 1600, 2000
    for slug, *_, emoji, top, bottom in ITEMS:
        im = Image.new('RGB', (W, H))
        d = ImageDraw.Draw(im)
        for y in range(H):
            t = y / (H - 1)
            d.line([(0, y), (W, y)], fill=tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)))
        glow = Image.new('L', (W, H), 0)
        ImageDraw.Draw(glow).ellipse([W * 0.15, H * 0.2, W * 0.85, H * 0.75], fill=90)
        im = Image.composite(Image.new('RGB', (W, H), (255, 255, 255)), im, glow.filter(ImageFilter.GaussianBlur(160)))
        e = Image.new('RGBA', (220, 220), (0, 0, 0, 0))
        ImageDraw.Draw(e).text((30, 10), emoji, font=emoji_font, embedded_color=True)
        e = e.crop(e.getbbox())
        scale = 900 / max(e.size)
        e = e.resize((int(e.width * scale), int(e.height * scale)), Image.LANCZOS)
        im.paste(e, ((W - e.width) // 2, (H - e.height) // 2), e)
        im.save(folder / f'{slug}.jpg', quality=82)
        thumb = im.copy()
        thumb.thumbnail((600, 600))
        thumb.save(folder / f'{slug}_thumb.jpg', quality=80)


def upload_photos(folder):
    """Uploads through curl: python.org builds of Python ship without the system's root certificates."""
    url, key = backend()
    tokens = {}
    for id_, email, _, pw in USERS:
        out = subprocess.run(['curl', '-sS', f'{url}/auth/v1/token?grant_type=password', '-H', f'apikey: {key}',
                              '-H', 'Content-Type: application/json', '-d', json.dumps({'email': email, 'password': pw})],
                             capture_output=True, text=True, check=True)
        session = json.loads(out.stdout)
        if 'access_token' not in session:
            sys.exit(f"Sign-in failed for {email}: {session.get('msg', out.stdout)}")
        tokens[id_] = session['access_token']
    for slug, owner, *_ in ITEMS:
        for name in (f'{slug}.jpg', f'{slug}_thumb.jpg'):
            out = subprocess.run(['curl', '-sS', '-X', 'POST', f'{url}/storage/v1/object/item-photos/{owner}/{name}',
                                  '-H', f'apikey: {key}', '-H', f'Authorization: Bearer {tokens[owner]}',
                                  '-H', 'Content-Type: image/jpeg', '-H', 'x-upsert: true', '--data-binary', f'@{folder / name}'],
                                 capture_output=True, text=True, check=True)
            if '"Key"' not in out.stdout:
                sys.exit(f"Upload failed for {name}: {out.stdout}")


def read_credentials():
    """Puts the passwords from Config/ReviewAccount.md back into USERS."""
    text = (ROOT / 'Config' / 'ReviewAccount.md').read_text()
    found = dict(re.findall(r"\| (\S+@ananeo\.app) \| (\S+) \|", text))
    USERS[:] = [(id_, email, name, found[email]) for id_, email, name, _ in USERS]


def photo_sql():
    return "\n".join(f"update public.items set photos = '{{{owner}/{slug}.jpg}}' where id = '{ITEM_ID[slug]}';" for slug, owner, *_ in ITEMS)


if __name__ == '__main__':
    photos_only = '--photos-only' in sys.argv
    if photos_only:
        read_credentials()
    else:
        write_credentials()
        print('1/3 accounts and content…')
        run_sql(build_sql())
    folder = ROOT / 'build' / 'review-photos'
    folder.mkdir(parents=True, exist_ok=True)
    print('2/3 photos…')
    draw_photos(folder)
    print('3/3 uploading…')
    upload_photos(folder)
    if photos_only:
        print('Uploaded. Now run this in the SQL editor so the listings point at the photos:\n')
        print(photo_sql())
    else:
        print('Done. Credentials are in Config/ReviewAccount.md.')
