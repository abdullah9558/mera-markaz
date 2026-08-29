import type { Metadata } from 'next';
import { DocumentShell } from '@/components/document-shell';
export const metadata: Metadata={title:'Terms of use'};
const sections=[{id:'service',label:'The service'},{id:'responsibility',label:'Your responsibility'},{id:'estimates',label:'Calculations & AI'},{id:'availability',label:'Availability'},{id:'changes',label:'Changes'}];
export default function Terms(){return <DocumentShell kicker="Effective 29 August 2026" title="Terms of use" intro="These terms describe the basic rules for using Mera Markaz." sections={sections}>
<section id="service"><h2>The service</h2><p>Mera Markaz provides personal finance organisation, utility helpers and informational tools. You may use the app for lawful personal purposes and must not attempt to disrupt, reverse engineer or misuse its services.</p></section>
<section id="responsibility"><h2>Your responsibility</h2><p>You are responsible for the accuracy of information you enter, safeguarding your device and account access, and reviewing results before relying on them. Do not share passwords or verification codes.</p></section>
<section id="estimates"><h2>Calculations and AI</h2><p>Utility, tax, Zakat, financial and AI results are estimates or informational guidance. Rates and rules can change, and AI can be inaccurate. Mera Markaz is not a substitute for professional financial, tax, legal or religious advice.</p></section>
<section id="availability"><h2>Availability</h2><p>Some functions depend on internet access, Firebase, Google, Meta or other services. Features may be temporarily unavailable and may change as the app develops.</p></section>
<section id="changes"><h2>Changes</h2><p>We may update the app and these terms. Material changes will be reflected through the app, website or store listing as appropriate. Continued use after an update means you accept the revised terms.</p></section>
</DocumentShell>}
