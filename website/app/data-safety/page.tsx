import type { Metadata } from 'next';
import { DocumentShell } from '@/components/document-shell';
export const metadata: Metadata={title:'Data safety'};
const sections=[{id:'guest',label:'Guest mode'},{id:'account',label:'Signed-in mode'},{id:'permissions',label:'Permissions'},{id:'choices',label:'Your choices'}];
export default function DataSafety(){return <DocumentShell kicker="Plain-language summary" title="Mera Markaz data safety" intro="A readable summary of the app’s main data flows. The full privacy policy provides additional detail." sections={sections}>
<section id="guest"><h2>Guest mode</h2><p>Guest finance activity is stored on the device. It remains when the app is force-closed and ends when the user signs into an account or logs out. Uninstalling or clearing app storage can remove it.</p></section>
<section id="account"><h2>Signed-in mode</h2><p>Email and Google sign-in use Firebase Authentication and the selected identity provider. Eligible account records use encrypted sync. Account information is not sold.</p></section>
<section id="permissions"><h2>Device permissions</h2><p>Mera Markaz may use biometric authentication when you enable it. Android settings let you review or revoke permissions. V1 does not request camera or notification permissions for excluded features.</p></section>
<section id="choices"><h2>Your choices</h2><ul><li>Continue as guest.</li><li>Choose email or Google sign-in.</li><li>Export and restore an encrypted local backup.</li><li>Request deletion of your account and associated information.</li></ul></section>
</DocumentShell>}
