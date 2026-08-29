import Link from 'next/link';

export function DocumentShell({ kicker, title, intro, sections, children }: { kicker: string; title: string; intro: string; sections: { id: string; label: string }[]; children: React.ReactNode }) {
  return <main><section className="document-hero"><div className="shell"><span className="kicker">{kicker}</span><h1>{title}</h1><p>{intro}</p></div></section><div className="shell document-layout"><aside className="side-nav">{sections.map(s => <Link key={s.id} href={`#${s.id}`}>{s.label}</Link>)}</aside><article className="prose">{children}</article></div></main>;
}
