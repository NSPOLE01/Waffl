//
//  LegalDocumentView.swift
//  Waffl
//
//  Created by Claude on 10/6/25.
//

import SwiftUI

struct LegalDocumentView: View {
    let title: String
    let content: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(content)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                    }
                }
            }
        }
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        LegalDocumentView(
            title: "Terms of Service",
            content: termsOfServiceContent
        )
    }

    private let termsOfServiceContent = """
TERMS OF SERVICE

Effective Date: October 6, 2025
Last Updated: October 6, 2025

1. ACCEPTANCE OF TERMS

By accessing or using the Waffl mobile application ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.

2. DESCRIPTION OF SERVICE

Waffl is a social video sharing platform that allows users to:
• Create and share short-form videos
• Connect with friends and other users
• Like, comment, and interact with content
• Discover new content through our recommendation system

3. USER ACCOUNTS

3.1 Account Creation
• You must provide accurate and complete information when creating an account
• You are responsible for maintaining the confidentiality of your account credentials
• You must be at least 13 years old to use our service
• Users under 18 require parental consent

3.2 Account Security
• You are responsible for all activities that occur under your account
• Notify us immediately of any unauthorized use of your account
• We reserve the right to suspend or terminate accounts that violate these Terms

4. USER CONTENT

4.1 Content Ownership
• You retain ownership of content you create and share
• By posting content, you grant Waffl a worldwide, non-exclusive license to use, distribute, and display your content within the App

4.2 Content Guidelines
You agree not to post content that:
• Violates any laws or regulations
• Infringes on intellectual property rights
• Contains hate speech, harassment, or bullying
• Depicts violence, illegal activities, or harmful behavior
• Contains sexually explicit or inappropriate material
• Spreads misinformation or false information

4.3 Content Moderation
• We reserve the right to review, remove, or restrict access to any content
• Violations may result in content removal, account suspension, or termination
• We use both automated systems and human review for content moderation

5. PROHIBITED CONDUCT

Users may not:
• Impersonate others or create fake accounts
• Engage in spam, harassment, or abusive behavior
• Attempt to hack, reverse engineer, or compromise the App
• Use automated systems to interact with the App
• Violate any applicable laws or regulations

6. PRIVACY

Your privacy is important to us. Please review our Privacy Policy, which explains how we collect, use, and protect your information.

7. INTELLECTUAL PROPERTY

7.1 Our Rights
• Waffl and its features are protected by copyright, trademark, and other intellectual property laws
• You may not copy, modify, or distribute our App or its content without permission

7.2 User Rights
• You retain rights to your original content
• By using our App, you do not gain rights to other users' content beyond what's permitted for normal App use

8. DISCLAIMERS

8.1 Service Availability
• The App is provided "as is" without warranties of any kind
• We do not guarantee uninterrupted or error-free service
• Features may change or be discontinued at any time

8.2 Content Disclaimer
• We are not responsible for user-generated content
• Users are solely responsible for their interactions with other users

9. LIMITATION OF LIABILITY

To the maximum extent permitted by law:
• Waffl shall not be liable for any indirect, incidental, or consequential damages
• Our total liability shall not exceed $100 or the amount you paid us in the past 12 months
• Some jurisdictions do not allow these limitations, so they may not apply to you

10. INDEMNIFICATION

You agree to indemnify and hold harmless Waffl from any claims, damages, or expenses arising from:
• Your use of the App
• Your violation of these Terms
• Your violation of any rights of another party

11. TERMINATION

11.1 Termination by You
• You may delete your account at any time through the App settings
• Account deletion will permanently remove your data and content

11.2 Termination by Us
We may suspend or terminate your account if you:
• Violate these Terms or our Community Guidelines
• Engage in illegal or harmful activities
• Create multiple accounts to circumvent restrictions

12. CHANGES TO TERMS

• We may modify these Terms at any time
• Changes will be posted in the App and become effective immediately
• Continued use of the App constitutes acceptance of modified Terms

13. GOVERNING LAW

These Terms are governed by the laws of [Your Jurisdiction], without regard to conflict of law principles.

14. DISPUTE RESOLUTION

14.1 Informal Resolution
Before pursuing formal legal action, you agree to first contact us to attempt informal resolution.

14.2 Arbitration
Any disputes will be resolved through binding arbitration rather than in court, except for small claims court actions.

15. SEVERABILITY

If any provision of these Terms is found to be unenforceable, the remaining provisions will remain in full force and effect.

16. CONTACT INFORMATION

For questions about these Terms, contact us at:
Email: legal@waffl.com
Address: [Your Business Address]

17. ENTIRE AGREEMENT

These Terms, along with our Privacy Policy and Community Guidelines, constitute the entire agreement between you and Waffl.

BY USING WAFFL, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY THESE TERMS OF SERVICE.
"""
}

struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(
            title: "Privacy Policy",
            content: privacyPolicyContent
        )
    }

    private let privacyPolicyContent = """
PRIVACY POLICY

Effective Date: October 6, 2025
Last Updated: October 6, 2025

1. INTRODUCTION

Waffl ("we," "our," or "us") respects your privacy and is committed to protecting your personal information. This Privacy Policy explains how we collect, use, share, and protect your information when you use our mobile application.

2. INFORMATION WE COLLECT

2.1 Information You Provide
• Account Information: Name, email address, username, password
• Profile Information: Profile photos, bio, preferences
• Content: Videos, comments, messages, and other content you create
• Communications: Messages you send to us or other users

2.2 Information We Collect Automatically
• Device Information: Device type, operating system, unique device identifiers
• Usage Information: How you interact with our App, features used, time spent
• Location Information: Approximate location based on IP address (with your consent for precise location)
• Log Information: IP address, browser type, crash reports, system activity

2.3 Information from Third Parties
• Social Media: If you connect social media accounts, we may receive profile information
• Analytics: We use third-party analytics services that may collect additional information

3. HOW WE USE YOUR INFORMATION

We use your information to:
• Provide and improve our services
• Create and maintain your account
• Enable content sharing and social features
• Personalize your experience and recommendations
• Communicate with you about our services
• Ensure platform safety and security
• Comply with legal obligations
• Conduct research and analytics

4. HOW WE SHARE YOUR INFORMATION

4.1 With Other Users
• Your profile information and content are visible to other users as per your privacy settings
• Your interactions (likes, comments, follows) may be visible to other users

4.2 With Service Providers
We share information with trusted third parties who help us operate our service:
• Cloud storage providers (Firebase/Google Cloud)
• Analytics services (Firebase Analytics)
• Communication services
• Content delivery networks

4.3 For Legal Reasons
We may share information when we believe it's necessary to:
• Comply with laws, regulations, or legal processes
• Protect the rights, property, or safety of Waffl, our users, or others
• Investigate and prevent fraud or security issues

4.4 Business Transfers
If Waffl is involved in a merger, acquisition, or sale, your information may be transferred to the new entity.

5. YOUR PRIVACY CHOICES

5.1 Account Settings
• Update your profile information and privacy settings
• Control who can see your content and send you friend requests
• Manage notification preferences

5.2 Content Control
• Delete your posts, comments, and other content
• Download a copy of your data
• Deactivate or delete your account

5.3 Communications
• Opt out of promotional emails
• Manage push notification settings
• Control in-app notifications

6. DATA RETENTION

• We retain your information as long as your account is active
• Some information may be retained longer for legal or safety reasons
• When you delete your account, we delete your personal information within 30 days
• Some anonymized or aggregated data may be retained for analytics

7. DATA SECURITY

We implement appropriate security measures to protect your information:
• Encryption in transit and at rest
• Regular security assessments
• Access controls and authentication
• Monitoring for suspicious activity

However, no method of transmission or storage is 100% secure.

8. CHILDREN'S PRIVACY

• Our service is not intended for children under 13
• We do not knowingly collect information from children under 13
• If we learn we have collected such information, we will delete it promptly
• Users aged 13-17 require parental consent

9. INTERNATIONAL DATA TRANSFERS

• Your information may be processed in countries other than your own
• We ensure appropriate safeguards are in place for international transfers
• By using our service, you consent to such transfers

10. COOKIES AND TRACKING TECHNOLOGIES

We use various technologies to collect information:
• Cookies and similar technologies
• Analytics tools
• Advertising identifiers
• Pixel tags and web beacons

You can control some of these through your device settings.

11. THIRD-PARTY SERVICES

Our App may contain links to third-party services. This Privacy Policy does not apply to those services. We encourage you to read their privacy policies.

12. CALIFORNIA PRIVACY RIGHTS

If you're a California resident, you have additional rights under the California Consumer Privacy Act (CCPA):
• Right to know what personal information we collect
• Right to delete personal information
• Right to opt-out of sale of personal information
• Right to non-discrimination

To exercise these rights, contact us at privacy@waffl.com.

13. EUROPEAN PRIVACY RIGHTS

If you're in the European Economic Area, you have rights under the General Data Protection Regulation (GDPR):
• Right of access
• Right to rectification
• Right to erasure
• Right to restrict processing
• Right to data portability
• Right to object
• Right to withdraw consent

To exercise these rights, contact us at privacy@waffl.com.

14. CHANGES TO THIS PRIVACY POLICY

• We may update this Privacy Policy from time to time
• We will notify you of significant changes through the App or email
• Continued use of our service constitutes acceptance of the updated policy

15. CONTACT US

If you have questions about this Privacy Policy or our privacy practices:

Email: privacy@waffl.com
Legal Department: legal@waffl.com
Address: [Your Business Address]

Data Protection Officer: dpo@waffl.com (for EU residents)

16. ADDITIONAL INFORMATION

16.1 Data Controller
Waffl is the data controller for your personal information.

16.2 Legal Basis for Processing (GDPR)
We process your information based on:
• Your consent
• Performance of our contract with you
• Our legitimate interests
• Legal obligations

16.3 Automated Decision Making
We use automated systems for:
• Content recommendations
• Safety and security measures
• Spam detection

You have the right to object to automated decision-making in certain circumstances.

BY USING WAFFL, YOU ACKNOWLEDGE THAT YOU HAVE READ AND UNDERSTOOD THIS PRIVACY POLICY AND AGREE TO OUR COLLECTION, USE, AND SHARING OF YOUR INFORMATION AS DESCRIBED.
"""
}