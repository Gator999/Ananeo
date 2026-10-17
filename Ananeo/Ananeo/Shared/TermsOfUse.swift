import Foundation

/// The terms people accept before using Ananeo.
/// Bump `version` whenever a change needs people to agree again. Everyone is asked to accept the
/// new version the next time they open the app.
enum TermsOfUse {
    static let version = 1
    static let lastUpdated = "October 17, 2026"
    static let contactEmail = "support@ananeo.app"
    static let minimumAge = 18

    enum Block: Hashable {
        case paragraph(String)
        case bullets([String])
    }

    struct Section: Identifiable {
        let title: String
        let blocks: [Block]

        var id: String { title }
    }

    static let prohibitedItems = [
        "Weapons, ammunition, explosives, and fireworks",
        "Drugs, drug paraphernalia, alcohol, tobacco, and vaping products",
        "Prescription or over-the-counter medicine",
        "Recalled products",
        "Child car seats, cribs, infant sleep products, and used helmets. Damage you can't see, or outdated safety standards, can make them unsafe.",
        "Hazardous materials, such as fuel, pesticides, pool chemicals, and damaged or swollen batteries",
        "Live animals",
        "Stolen or counterfeit goods",
        "Adult content and sexual products",
        "Anything offered for money. Ananeo is for giving and swapping only.",
        "Anything else that's illegal to own or give away where you live",
    ]

    static let sections: [Section] = [
        Section(title: "Welcome to Ananeo", blocks: [
            .paragraph("Ananeo connects people who have things they no longer need with people who can use them. Everything on Ananeo is free: you give, swap, or pass things on, and nobody pays."),
            .paragraph("These terms are an agreement between you and Ananeo. By tapping I Agree, you accept them."),
        ]),
        Section(title: "Who Can Use Ananeo", blocks: [
            .bullets([
                "You must be at least \(minimumAge) years old.",
                "Use one account, your own, and keep it to yourself.",
                "You're responsible for what happens on your account.",
            ]),
        ]),
        Section(title: "Zero Tolerance for Objectionable Content and Abuse", blocks: [
            .paragraph("Ananeo has no tolerance for objectionable content or abusive users. Don't post, send, or list anything that:"),
            .bullets([
                "Harasses, bullies, threatens, or intimidates anyone",
                "Is hateful, or demeans people for their race, ethnicity, national origin, religion, gender, gender identity, sexual orientation, disability, or age",
                "Is sexually explicit",
                "Shows or encourages violence or self-harm",
                "Is spam, a scam, or misleading",
                "Shares someone else's private information, including their address, without their permission",
                "Impersonates someone else",
                "Breaks the law or someone else's rights, such as copyright",
            ]),
            .paragraph("We review every report within 24 hours. We remove content that breaks these terms and ban the people who post it, without warning."),
        ]),
        Section(title: "What You Can't List", blocks: [
            .paragraph("Only list physical items you own and have the right to give away. You can't list:"),
            .bullets(prohibitedItems),
        ]),
        Section(title: "Meeting Up and Handing Off", blocks: [
            .paragraph("Ananeo doesn't own, inspect, or guarantee anything listed. Items are offered as they are, and it's up to you to decide whether something is safe and right for you."),
            .paragraph("Meet in a public place when you can, tell someone where you're going, and trust your instincts. Your exact address is never shown. Share it only when you choose to."),
            .paragraph("Exchanges happen between members. To the fullest extent the law allows, Ananeo isn't responsible for items, meetups, or what members do."),
        ]),
        Section(title: "Reporting and Blocking", blocks: [
            .paragraph("Report a listing, a message, or a person from the ••• menu, or by touching and holding a message. Block anyone to stop seeing their listings and messages. Blocking someone also ends any pickup in progress between you."),
        ]),
        Section(title: "Your Content", blocks: [
            .paragraph("You keep ownership of the photos and words you post. You give Ananeo permission to store them and show them to other members so the app works. Don't post photos of other people without their permission."),
        ]),
        Section(title: "Your Account", blocks: [
            .paragraph("You can delete your account at any time from the account menu on the Impact tab. That removes your listings, messages, and history. We may suspend or ban accounts that break these terms."),
        ]),
        Section(title: "Changes to These Terms", blocks: [
            .paragraph("We may update these terms. When we do, we'll ask you to agree to the new version before you keep using Ananeo."),
        ]),
        Section(title: "Contact Us", blocks: [
            .paragraph("Questions, concerns, or something that needs urgent attention? Email \(contactEmail)."),
        ]),
    ]
}
