import "./prototype.css";

export const metadata = {
  title: "XARK 2030 Prototypes",
  description: "Spatial OS Concepts",
};

export default function PrototypeLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="xark-prototype-container">
      {children}
    </div>
  );
}
