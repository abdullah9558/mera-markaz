import type { Metadata } from 'next';
import { DocumentShell } from '@/components/document-shell';

export const metadata: Metadata = { title: 'Privacy policy' };

const sections = [
  { id: 'overview', label: 'Overview' },
  { id: 'collect', label: 'Information handled' },
  { id: 'use', label: 'How it is used' },
  { id: 'sharing', label: 'Service providers' },
  { id: 'control', label: 'Your controls' },
  { id: 'security', label: 'Security and retention' },
  { id: 'contact', label: 'Contact' },
];

export default function Privacy() {
  return <DocumentShell
    kicker="Effective 20 September 2026"
    title="Privacy policy"
    intro="This policy describes the Mera Markaz V1 Android app and this website."
    sections={sections}
  >
    <section id="overview"><h2>Overview</h2><p>Mera Markaz is a personal finance and utility app published by Logivyre Labs. You can use guest mode without an account, or create an account to use signed-in features. The V1 app does not display ads or offer online AI.</p></section>
    <section id="collect"><h2>Information we handle</h2><ul>
      <li><strong>Account and profile:</strong> your name, email address, optional profile photo and authentication-provider identifier when you sign in with email or Google.</li>
      <li><strong>Information you enter:</strong> expenses, budgets, savings goals, informal debt ledgers and payments, plus calculator inputs and app preferences.</li>
      <li><strong>Technical information:</strong> limited app, device and security information needed for authentication, app protection, synchronisation and service reliability.</li>
      <li><strong>Support:</strong> the information you choose to include in feedback or support requests.</li>
    </ul></section>
    <section id="use"><h2>How information is used</h2><p>We use this information to provide your requested features, maintain an account when you choose to create one, protect the service, synchronise eligible signed-in data, and respond to support requests. Guest financial activity is stored on your device. We do not sell your personal information.</p></section>
    <section id="sharing"><h2>Service providers</h2><p>Google Firebase provides account authentication, app protection and supported encrypted synchronisation. Google Sign-In is available when you choose it. These providers process the information needed to deliver those services under their own privacy terms. V1 does not send financial summaries to an online AI service.</p></section>
    <section id="control"><h2>Your controls</h2><ul>
      <li>Continue as a guest and keep financial activity on the device.</li>
      <li>Choose whether to create an account and use signed-in synchronisation.</li>
      <li>Edit your profile, export or restore a local encrypted backup, and manage app preferences.</li>
      <li>Sign out or request deletion of your account and associated data. See the <a className="text-link" href="/account-deletion">account-deletion instructions</a>.</li>
    </ul></section>
    <section id="security"><h2>Security and retention</h2><p>Financial data is protected with local encryption, and eligible signed-in records use encrypted synchronisation. No security measure is perfect. Guest data remains on the device until you sign into an existing account, log out, clear app storage or uninstall the app; creating a new account from guest mode can attach that activity to the new account. Account data is retained while needed to provide the service or meet security and legal obligations, and account deletion can be requested from the app or through support.</p></section>
    <section id="contact"><h2>Contact</h2><p>For privacy questions or account requests, email <a className="text-link" href="mailto:muhammadabdullah9558@gmail.com">muhammadabdullah9558@gmail.com</a>. Never send passwords or verification codes.</p></section>
  </DocumentShell>;
}
