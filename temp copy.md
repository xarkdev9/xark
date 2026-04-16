import React from "react";
import { motion } from "framer-motion";
import { Check, MessageCircle, Plane, Sparkles, Users } from "lucide-react";

type MomentCard = {
  id: string;
  kind: "vote" | "reply" | "confirm" | "group_ask";
  source: string;
  ask: string;
  why: string;
  accent: string;
  image: string;
};

const MOMENTS: MomentCard[] = [
  {
    id: "flight",
    kind: "vote",
    source: "Swiss Alps",
    ask: "Vote on Zurich flight",
    why: "3 waiting · closes in 6h",
    accent: "#0f766e",
    image:
      "linear-gradient(180deg, rgba(255,255,255,0.06), rgba(255,255,255,0.22)), linear-gradient(135deg, #d8e6f6 0%, #f6dcc3 54%, #d4dde8 100%)",
  },
  {
    id: "sarah",
    kind: "reply",
    source: "Sarah",
    ask: "Asked if Swiss is locked",
    why: "private reply · 4m ago",
    accent: "#ff2d55",
    image:
      "linear-gradient(180deg, rgba(255,255,255,0.06), rgba(255,255,255,0.16)), linear-gradient(135deg, #f6d7e4 0%, #ecd8ea 42%, #f7eadf 100%)",
  },
  {
    id: "family",
    kind: "group_ask",
    source: "Family",
    ask: "Mom asked about Sunday lunch",
    why: "buried in banter",
    accent: "#2563eb",
    image:
      "linear-gradient(180deg, rgba(255,255,255,0.05), rgba(255,255,255,0.18)), linear-gradient(135deg, #dce6ff 0%, #d7e1ff 44%, #f1e5da 100%)",
  },
  {
    id: "bali",
    kind: "confirm",
    source: "Bali Trip",
    ask: "Confirm villa deposit",
    why: "2 blocked",
    accent: "#ff6a3d",
    image:
      "linear-gradient(180deg, rgba(255,255,255,0.05), rgba(255,255,255,0.18)), linear-gradient(135deg, #b8ebf2 0%, #8ed8ea 42%, #f2d2bf 100%)",
  },
  {
    id: "goa",
    kind: "vote",
    source: "Goa Group",
    ask: "Break the hotel tie",
    why: "3–3 split right now",
    accent: "#7c3aed",
    image:
      "linear-gradient(180deg, rgba(255,255,255,0.05), rgba(255,255,255,0.18)), linear-gradient(135deg, #e8defe 0%, #d9d0ff 46%, #f7dfcc 100%)",
  },
];

export default function CinematicCascadePrototype() {
  return (
    <div className="min-h-screen bg-[#f4eee7] text-[#181312]">
      <div className="mx-auto max-w-[1450px] px-6 py-8">
        <div className="max-w-5xl">
          <div className="inline-flex items-center rounded-full border border-black/5 bg-white/82 px-3 py-1.5 text-[11px] font-medium uppercase tracking-[0.18em] text-[#6f665f] shadow-sm">
            2030 home · cinematic cascade
          </div>
          <h1 className="mt-5 text-4xl font-semibold tracking-tight sm:text-5xl lg:text-6xl">
            Five things. One glance.
            <span className="block text-[#6f665f]">No boards. No pills. No admin chrome.</span>
          </h1>
          <p className="mt-4 max-w-4xl text-base leading-8 text-[#6f665f] sm:text-lg">
            The breakthrough is not a list and not a one-card carousel. It is a cinematic cascade: five immersive response surfaces are all visible at once, each reduced to an extracted ask. The user feels priority immediately because the stack itself becomes the morning glance.
          </p>
        </div>

        <div className="mt-10 grid gap-3 sm:grid-cols-4">
          {[
            "5 immediate things visible",
            "immersive cards, not rows",
            "direct asks never hide",
            "thumb acts on the front surface",
          ].map((item) => (
            <div key={item} className="rounded-full border border-black/5 bg-white/76 px-4 py-3 text-sm text-[#3b312d] shadow-sm">
              {item}
            </div>
          ))}
        </div>

        <div className="mt-12 grid gap-8 xl:grid-cols-3">
          <CascadeScreen
            eyebrow="Screen 1"
            title="Morning glance"
            subtitle="Five obligations visible at once"
            cards={MOMENTS}
            stateLabel="5 now"
          />
          <CascadeScreen
            eyebrow="Screen 2"
            title="Critical 1:1 protected"
            subtitle="Private reply promoted to the front"
            cards={[MOMENTS[1], MOMENTS[0], MOMENTS[2], MOMENTS[3], MOMENTS[4]]}
            stateLabel="1 direct · 4 follow"
          />
          <CascadeScreen
            eyebrow="Screen 3"
            title="Calmer morning"
            subtitle="Only two truly urgent, three warm"
            cards={[MOMENTS[0], MOMENTS[2], MOMENTS[4], MOMENTS[3], MOMENTS[1]]}
            stateLabel="2 urgent · 3 warm"
          />
        </div>
      </div>
    </div>
  );
}

function CascadeScreen({
  eyebrow,
  title,
  subtitle,
  cards,
  stateLabel,
}: {
  eyebrow: string;
  title: string;
  subtitle: string;
  cards: MomentCard[];
  stateLabel: string;
}) {
  return (
    <div>
      <div className="mb-4 px-2">
        <div className="text-[12px] font-medium uppercase tracking-[0.16em] text-[#8a7c73]">{eyebrow}</div>
        <div className="mt-1 text-[26px] font-semibold tracking-tight text-[#181312]">{title}</div>
        <div className="mt-1 text-sm text-[#6f665f]">{subtitle}</div>
      </div>

      <div className="relative mx-auto h-[844px] w-[390px] overflow-hidden rounded-[40px] border border-black/5 bg-[#f7f3ee] shadow-[0_36px_110px_rgba(24,19,18,0.10)]">
        <div className="pointer-events-none absolute inset-x-0 top-0 z-10 h-24 bg-[linear-gradient(180deg,rgba(247,243,238,0.96),rgba(247,243,238,0.4),rgba(247,243,238,0))]" />

        <div className="relative z-20 px-5 pt-4">
          <div className="flex items-center justify-between text-[11px] font-semibold uppercase tracking-[0.2em] text-[#8b7f75]">
            <span>9:41</span>
            <span>Home</span>
          </div>
          <div className="mt-5 flex items-end justify-between">
            <div>
              <div className="flex items-center gap-2 text-sm text-[#8b7f75]">
                <Sparkles className="h-4 w-4" />
                Morning clarity
              </div>
              <div className="mt-1 text-[34px] font-semibold leading-none tracking-tight">Needs you</div>
            </div>
            <div className="text-right">
              <div className="text-[30px] font-semibold leading-none tracking-tight text-[#181312]">5</div>
              <div className="mt-1 text-[11px] uppercase tracking-[0.18em] text-[#8a7c73]">{stateLabel}</div>
            </div>
          </div>
        </div>

        <div className="absolute left-4 top-[154px] bottom-10 z-30 flex w-5 flex-col items-center justify-start gap-6">
          {cards.map((card, index) => (
            <motion.div
              key={card.id}
              animate={{ opacity: index === 0 ? [1, 0.7, 1] : 0.5, scale: index === 0 ? [1, 1.15, 1] : 1 }}
              transition={{ duration: 2.8, repeat: Infinity, ease: "easeInOut" }}
              className="rounded-full"
              style={{
                width: index === 0 ? 8 : 6,
                height: index === 0 ? 32 : 22,
                background: card.accent,
                boxShadow: index === 0 ? `0 0 18px ${card.accent}` : `0 0 8px ${card.accent}66`,
              }}
            />
          ))}
        </div>

        <div className="absolute inset-x-0 top-[146px] bottom-0 px-4 pb-8">
          <div className="relative h-full">
            {cards.map((card, index) => (
              <CinematicPlane key={card.id} card={card} index={index} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function CinematicPlane({ card, index }: { card: MomentCard; index: number }) {
  const top = index * 84;
  const height = index === 0 ? 430 : 230;
  const scale = 1 - index * 0.018;
  const opacity = 1 - index * 0.08;
  const front = index === 0;

  return (
    <motion.div
      initial={{ opacity: 0, y: top + 30, scale: 0.98 }}
      animate={{ opacity, y: top, scale }}
      transition={{ type: "spring", stiffness: 120, damping: 22, delay: index * 0.04 }}
      className="absolute inset-x-0 overflow-hidden rounded-[34px] border border-white/35 shadow-[0_26px_70px_rgba(22,18,16,0.10)] backdrop-blur-xl"
      style={{
        height,
        background: card.image,
        zIndex: 20 - index,
      }}
    >
      <div className="absolute inset-0 bg-[linear-gradient(180deg,rgba(255,255,255,0.02),rgba(255,255,255,0.12),rgba(255,255,255,0.72))]" />
      <div className="relative flex h-full flex-col justify-between p-5">
        <div>
          <div className="flex items-center gap-3">
            <div className="h-2.5 w-2.5 rounded-full shadow-[0_0_14px_rgba(255,77,109,0.45)]" style={{ background: card.accent }} />
            <div className="truncate text-[12px] font-medium uppercase tracking-[0.18em] text-[#3b312d]">{card.source}</div>
            <div className="truncate text-[12px] uppercase tracking-[0.14em] text-[#7b7069]">{kindLabel(card.kind)}</div>
          </div>

          <div className={`mt-4 ${front ? "text-[34px]" : "text-[22px]"} font-semibold leading-[0.96] tracking-tight text-[#181312]`}>
            {front ? card.ask : `${card.ask}`}
          </div>
          <div className={`mt-2 ${front ? "text-[16px]" : "text-[13px]"} leading-6 text-[#4f4742]`}>
            {card.why}
          </div>
        </div>

        {front ? (
          <div className="flex items-center gap-4 text-sm font-medium text-[#181312]">
            <button className="inline-flex items-center gap-2 border-b border-black/20 pb-1">
              {primaryIcon(card.kind)}
              Act now
            </button>
            <button className="inline-flex items-center gap-2 border-b border-black/10 pb-1 text-[#5f5752]">
              Later
            </button>
          </div>
        ) : (
          <div className="h-8" />
        )}
      </div>
    </motion.div>
  );
}

function kindLabel(kind: MomentCard["kind"]) {
  switch (kind) {
    case "vote":
      return "vote";
    case "reply":
      return "private";
    case "confirm":
      return "confirm";
    case "group_ask":
      return "group ask";
    default:
      return "now";
  }
}

function primaryIcon(kind: MomentCard["kind"]) {
  switch (kind) {
    case "vote":
      return <Plane className="h-4 w-4" />;
    case "reply":
      return <MessageCircle className="h-4 w-4" />;
    case "confirm":
      return <Check className="h-4 w-4" />;
    case "group_ask":
      return <Users className="h-4 w-4" />;
    default:
      return <Sparkles className="h-4 w-4" />;
  }
}


all the colors used in the current prototype.

Core neutral palette
#f4eee7 — outer page background
#f7f3ee — phone canvas background
#181312 — primary ink / headline text
#6f665f — secondary body text
#3b312d — label / chip text
#8a7c73 — eyebrow / helper label
#8b7f75 — status-bar / subtle chrome text
#7b7069 — state label text
#5f5752 — secondary action text
#4f4742 — description text on cards
Accent colors for the 5 cinematic cards
#0f766e — Swiss Alps / vote
#ff2d55 — Sarah / private reply
#2563eb — Family / group ask
#ff6a3d — Bali Trip / confirm
#7c3aed — Goa Group / vote
Card image gradient colors
Card 1 — Swiss Alps
#d8e6f6
#f6dcc3
#d4dde8
Card 2 — Sarah
#f6d7e4
#ecd8ea
#f7eadf
Card 3 — Family
#dce6ff
#d7e1ff
#f1e5da
Card 4 — Bali Trip
#b8ebf2
#8ed8ea
#f2d2bf
Card 5 — Goa Group
#e8defe
#d9d0ff
#f7dfcc
White / black translucent surfaces used through Tailwind and gradients

These are not hex colors, but they are part of the visual system:

White-based
white / 82%
white / 76%
white / 35%
rgba(255,255,255,0.96)
rgba(255,255,255,0.4)
rgba(255,255,255,0.06)
rgba(255,255,255,0.22)
rgba(255,255,255,0.16)
rgba(255,255,255,0.05)
rgba(255,255,255,0.18)
rgba(255,255,255,0.02)
rgba(255,255,255,0.12)
rgba(255,255,255,0.72)
Black / shadow-based
black / 5%
black / 4%
black / 20%
black / 10%
rgba(22,18,16,0.10)
Dynamic glow variants

These are generated from the accent colors:

each accent color also appears as a glow with 66 alpha suffix, for example:
#0f766e66
#ff2d5566
#2563eb66
#ff6a3d66
#7c3aed66