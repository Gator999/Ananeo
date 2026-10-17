// The terms people accept before using Ananeo. This mirrors Shared/TermsOfUse.swift in the iOS app:
// keep the two in step, and bump `version` in both whenever a change needs people to agree again.

export const TERMS_VERSION = 1
export const TERMS_LAST_UPDATED = 'October 17, 2026'
export const CONTACT_EMAIL = 'support@ananeo.app'
export const MINIMUM_AGE = 18

export type TermsBlock = { kind: 'paragraph'; text: string } | { kind: 'bullets'; items: string[] }

export interface TermsSection {
  title: string
  blocks: TermsBlock[]
}

const p = (text: string): TermsBlock => ({ kind: 'paragraph', text })
const bullets = (items: string[]): TermsBlock => ({ kind: 'bullets', items })

export const PROHIBITED_ITEMS = [
  'Weapons, ammunition, explosives, and fireworks',
  'Drugs, drug paraphernalia, alcohol, tobacco, and vaping products',
  'Prescription or over-the-counter medicine',
  'Recalled products',
  "Child car seats, cribs, infant sleep products, and used helmets. Damage you can't see, or outdated safety standards, can make them unsafe.",
  'Hazardous materials, such as fuel, pesticides, pool chemicals, and damaged or swollen batteries',
  'Live animals',
  'Stolen or counterfeit goods',
  'Adult content and sexual products',
  'Anything offered for money. Ananeo is for giving and swapping only.',
  "Anything else that's illegal to own or give away where you live",
]

export const TERMS_SECTIONS: TermsSection[] = [
  {
    title: 'Welcome to Ananeo',
    blocks: [
      p('Ananeo connects people who have things they no longer need with people who can use them. Everything on Ananeo is free: you give, swap, or pass things on, and nobody pays.'),
      p('These terms are an agreement between you and Ananeo. By choosing I Agree, you accept them.'),
    ],
  },
  {
    title: 'Who Can Use Ananeo',
    blocks: [
      bullets([
        `You must be at least ${MINIMUM_AGE} years old.`,
        'Use one account, your own, and keep it to yourself.',
        "You're responsible for what happens on your account.",
      ]),
    ],
  },
  {
    title: 'Zero Tolerance for Objectionable Content and Abuse',
    blocks: [
      p("Ananeo has no tolerance for objectionable content or abusive users. Don't post, send, or list anything that:"),
      bullets([
        'Harasses, bullies, threatens, or intimidates anyone',
        'Is hateful, or demeans people for their race, ethnicity, national origin, religion, gender, gender identity, sexual orientation, disability, or age',
        'Is sexually explicit',
        'Shows or encourages violence or self-harm',
        'Is spam, a scam, or misleading',
        "Shares someone else's private information, including their address, without their permission",
        'Impersonates someone else',
        "Breaks the law or someone else's rights, such as copyright",
      ]),
      p('We review every report within 24 hours. We remove content that breaks these terms and ban the people who post it, without warning.'),
    ],
  },
  {
    title: "What You Can't List",
    blocks: [p("Only list physical items you own and have the right to give away. You can't list:"), bullets(PROHIBITED_ITEMS)],
  },
  {
    title: 'Meeting Up and Handing Off',
    blocks: [
      p("Ananeo doesn't own, inspect, or guarantee anything listed. Items are offered as they are, and it's up to you to decide whether something is safe and right for you."),
      p("Meet in a public place when you can, tell someone where you're going, and trust your instincts. Your exact address is never shown. Share it only when you choose to."),
      p("Exchanges happen between members. To the fullest extent the law allows, Ananeo isn't responsible for items, meetups, or what members do."),
    ],
  },
  {
    title: 'Reporting and Blocking',
    blocks: [
      p('Report a listing, a message, or a person from the ••• menu in the iOS app, or by touching and holding a message. Block anyone to stop seeing their listings and messages. Blocking someone also ends any pickup in progress between you.'),
    ],
  },
  {
    title: 'Your Content',
    blocks: [
      p("You keep ownership of the photos and words you post. You give Ananeo permission to store them and show them to other members so the app works. Don't post photos of other people without their permission."),
    ],
  },
  {
    title: 'Your Account',
    blocks: [
      p('You can delete your account at any time from the Impact tab. That removes your listings, messages, and history. We may suspend or ban accounts that break these terms.'),
    ],
  },
  {
    title: 'Changes to These Terms',
    blocks: [p("We may update these terms. When we do, we'll ask you to agree to the new version before you keep using Ananeo.")],
  },
  {
    title: 'Contact Us',
    blocks: [p(`Questions, concerns, or something that needs urgent attention? Email ${CONTACT_EMAIL}.`)],
  },
]
