import type { Metadata } from 'next';
import { Geist } from 'next/font/google';
import Image from 'next/image';
import Link from 'next/link';
import { ExternalLink } from 'lucide-react';
import './globals.css';

const geist = Geist({ variable: '--font-geist', subsets: ['latin'] });
export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? 'https://mera-markaz-guide.muhammadabdullah589.chatgpt.site'),
  title: { default: 'Mera Markaz — Your Money. Your Markaz.', template: '%s | Mera Markaz' },
  description: 'Pakistan-first personal finance, bills, savings and utility tools in English and Urdu.',
  icons: { icon: '/media/meramarkaz-logo.png' },
  openGraph: { title: 'Mera Markaz', description: 'Everything you need. One place.', images: ['/media/meramarkaz-thumbnail.png'] },
  twitter: { card: 'summary_large_image', title: 'Mera Markaz', description: 'Everything you need. One place.', images: ['/media/meramarkaz-thumbnail.png'] },
};
const nav = [['Features', '/#features'], ['How it works', '/guide'], ['Privacy', '/privacy'], ['Support', '/support']];
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body className={geist.variable}>
    <header className="site-header"><div className="shell nav-wrap"><Link className="brand" href="/"><Image src="/media/meramarkaz-logo.png" alt="Mera Markaz logo" width={44} height={44} /><span>Mera<span>Markaz</span></span></Link><nav aria-label="Main navigation">{nav.map(([label, href]) => <Link key={href} href={href}>{label}</Link>)}</nav><Link className="nav-cta" href="/guide">Get started <ExternalLink size={15} /></Link></div></header>
    {children}
    <footer><div className="shell footer-grid"><div><Link className="brand footer-brand" href="/"><Image src="/media/meramarkaz-logo.png" alt="" width={42} height={42} /><span>Mera<span>Markaz</span></span></Link><p>A free Pakistan-first finance and utility companion by Logivyre Labs.</p></div><div><h3>Product</h3><Link href="/#features">Features</Link><Link href="/guide">User guide</Link><Link href="/support">Support</Link></div><div><h3>Trust</h3><Link href="/privacy">Privacy policy</Link><Link href="/data-safety">Data safety</Link><Link href="/account-deletion">Delete account</Link><Link href="/terms">Terms</Link></div></div><div className="shell footer-bottom"><span>© {new Date().getFullYear()} Logivyre Labs</span><span>Made thoughtfully for Pakistan</span></div></footer>
  </body></html>;
}
