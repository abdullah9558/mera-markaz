import type { Metadata } from 'next';
import Link from 'next/link';
import { DocumentShell } from '@/components/document-shell';
export const metadata: Metadata={title:'Support'};
const sections=[{id:'quick',label:'Quick help'},{id:'signin',label:'Sign-in help'},{id:'data',label:'Data & sync'},{id:'ai',label:'AI help'},{id:'contact',label:'Contact support'}];
export default function Support(){return <DocumentShell kicker="Help centre" title="How can we help?" intro="Try these common solutions first. If you still need help, use the support channel shown on the official Google Play listing." sections={sections}>
<section id="quick"><h2>Quick checks</h2><ol className="steps"><li>Update Mera Markaz from Google Play.</li><li>Restart the app and confirm your internet connection.</li><li>For sign-in or online AI, make sure the phone date and time are automatic.</li><li>Do not clear app storage unless you understand that local guest data may be removed.</li></ol></section>
<section id="signin"><h2>Sign-in help</h2><p>For Google or Facebook, use an account already available on the phone and complete the provider’s prompts. For email, check the address carefully and use the password-reset option when needed. Guest mode does not require an account.</p></section>
<section id="data"><h2>Data and sync</h2><p>Signed-in information may take a moment to restore after a new installation. Keep the app open with a stable connection. Guest information belongs to that installation and is not restored to another phone unless it was attached to a newly created account.</p></section>
<section id="ai"><h2>Markaz AI help</h2><p>Guest and offline use falls back to the local assistant. Online AI requires a signed-in account, internet access, consent and successful app verification. If online AI is unavailable, the app should show a local answer instead.</p></section>
<section id="contact"><h2>Contact support</h2><div className="contact-card"><h3>Before you message us</h3><p>Include your app version, phone model, Android version, what you expected, what happened and a screenshot without private financial information.</p><p>Use the public support email on the Google Play listing. If you are requesting deletion, follow the <Link className="text-link" href="/account-deletion">account deletion instructions</Link>.</p></div></section>
</DocumentShell>}
