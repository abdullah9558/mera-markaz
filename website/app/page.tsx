import Image from 'next/image';
import Link from 'next/link';
import { ArrowRight, BadgeCheck, Bot, Calculator, CircleDollarSign, CloudCog, Fuel, Languages, LockKeyhole, PiggyBank, ReceiptText, ShieldCheck, Smartphone, Sparkles, UserRoundCheck, WalletCards, Zap } from 'lucide-react';
import appData from '@/content/app-data.json';

const features = [
  { icon: WalletCards, title: 'Money in one view', text: 'Track everyday expenses, income, savings goals and recurring commitments from a focused dashboard.' },
  { icon: ReceiptText, title: 'Bills & utilities', text: 'Keep electricity, fuel and household costs organised with Pakistan-focused tools and calculators.' },
  { icon: Bot, title: 'Markaz AI', text: 'Ask questions about a limited summary of your finances. Online AI is optional and always requires consent.' },
  { icon: Languages, title: 'English & Urdu', text: 'Use the app in the language that feels natural, with right-to-left support throughout the experience.' },
  { icon: CloudCog, title: 'Secure sync', text: 'Signed-in users can keep encrypted data available across supported devices; guest mode remains local.' },
  { icon: ShieldCheck, title: 'Privacy by design', text: 'Sensitive records stay protected, complete records are not sent to AI, and online AI can be disabled.' },
];

const tools = [[Zap, 'Electricity'], [Fuel, 'Fuel'], [Calculator, 'Tax'], [PiggyBank, 'Savings'], [CircleDollarSign, 'Zakat'], [Smartphone, 'Solar']] as const;

export default function Home() {
  return <main>
    <section className="hero" id="home"><div className="hero-glow" /><div className="shell hero-grid">
      <div className="hero-copy"><div className="eyebrow"><Sparkles size={16} /> Pakistan-first personal finance</div><h1>Your money.<br /><span>Your markaz.</span></h1><p className="hero-lede">Mera Markaz brings expenses, bills, savings and smart financial tools into one calm, bilingual app—built for everyday life in Pakistan.</p><div className="hero-actions"><Link className="button primary" href="/guide">Learn how it works <ArrowRight size={18} /></Link><Link className="button secondary" href="/privacy">Read our privacy policy</Link></div><div className="trust-row"><span><BadgeCheck size={17} /> Free to use</span><span><LockKeyhole size={17} /> Encrypted data</span><span><Languages size={17} /> English + Urdu</span></div></div>
      <div className="hero-visual"><Image src="/media/mera-markaz-banner.png" alt="Mera Markaz mobile app showing its finance tools" width={1672} height={941} priority /><div className="version-chip">Current release <strong>v{appData.version}</strong></div></div>
    </div></section>
    <section className="section" id="features"><div className="shell"><div className="section-heading"><div><span className="kicker">Built around real life</span><h2>One app. The tools you reach for every day.</h2></div><p>No fragmented spreadsheets or confusing finance jargon. Mera Markaz keeps useful actions close and understandable.</p></div><div className="feature-grid">{features.map(({ icon: Icon, title, text }) => <article className="feature-card" key={title}><span className="icon-box"><Icon /></span><h3>{title}</h3><p>{text}</p></article>)}</div></div></section>
    <section className="section tools-section"><div className="shell tool-layout"><div><span className="kicker">Pakistan-focused toolkit</span><h2>Useful calculations, without the clutter.</h2><p>Plan common household and financial decisions using clearly separated tools, then keep the results alongside the rest of your money picture.</p><Link className="text-link" href="/guide">View the complete user guide <ArrowRight size={17} /></Link></div><div className="tool-grid">{tools.map(([Icon, label]) => <div className="tool-pill" key={label}><Icon /><span>{label}</span></div>)}</div></div></section>
    <section className="section security-section" id="security"><div className="shell security-card"><div className="security-mark"><LockKeyhole /></div><div><span className="kicker">Your information, handled carefully</span><h2>Private by default. Online only when you choose.</h2></div><div className="security-points"><p><UserRoundCheck /> Guest activity stays on the device and the session continues until you sign in or log out.</p><p><ShieldCheck /> Account data is protected in transit and encrypted before supported cloud backup.</p><p><Bot /> Gemini receives only a limited financial summary after consent—not passwords, tokens or full records.</p></div><Link className="button light" href="/privacy">See exactly how data is handled <ArrowRight size={18} /></Link></div></section>
    <section className="section cta-section"><div className="shell cta-card"><Image src="/media/meramarkaz-logo.png" alt="Mera Markaz" width={180} height={180} /><div><span className="kicker">Getting started</span><h2>Make Mera Markaz your everyday money companion.</h2><p>Read the installation and usage guide, find answers, or contact support.</p></div><div className="cta-actions"><Link className="button primary" href="/guide">Open user guide</Link><Link className="button secondary" href="/support">Get support</Link></div></div></section>
  </main>;
}
