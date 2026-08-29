import type { Metadata } from 'next';
import { DocumentShell } from '@/components/document-shell';
export const metadata: Metadata={title:'Data safety'};
const sections=[{id:'guest',label:'Guest mode'},{id:'account',label:'Signed-in mode'},{id:'ai',label:'Online AI'},{id:'permissions',label:'Permissions'},{id:'choices',label:'Your choices'}];
export default function DataSafety(){return <DocumentShell kicker="Plain-language summary" title="Mera Markaz data safety" intro="A readable summary of the app’s main data flows. The full privacy policy provides additional detail." sections={sections}>
<section id="guest"><h2>Guest mode</h2><p>Guest finance activity is stored on the device. It remains when the app is force-closed and ends when the user signs into an account or logs out. Uninstalling or clearing app storage can remove it.</p></section>
<section id="account"><h2>Signed-in mode</h2><p>Email, Google and Facebook sign-in use Firebase Authentication and the selected identity provider. Eligible account data can use encrypted sync and backup. Account information is not sold.</p></section>
<section id="ai"><h2>Online AI</h2><p>Online Markaz AI is optional, requires consent and sends a limited financial summary to Google Gemini for personalised assistance. Guest mode uses local processing. Complete records and authentication secrets are excluded.</p></section>
<section id="permissions"><h2>Device permissions</h2><p>Mera Markaz may request notifications, biometric authentication, camera or photo access only when related features are used. Android settings let you review or revoke permissions. Some features may stop working after permission is removed.</p></section>
<section id="choices"><h2>Your choices</h2><ul><li>Continue as guest.</li><li>Choose an account provider.</li><li>Decline or withdraw online-AI consent.</li><li>Control notifications and device permissions.</li><li>Delete your account and associated information.</li></ul></section>
</DocumentShell>}
