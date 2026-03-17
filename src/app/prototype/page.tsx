'use client';

import React, { useState, useEffect, useRef, useMemo } from 'react';
import { motion, AnimatePresence, useMotionValue, useTransform, animate } from 'framer-motion';

// ─── Xark Theme (Hearth Light) ──────────────────────────────

const T = {
  void: '#F8F7F4',
  ink: '#111111',
  accent: '#FF6B35',
  cyan: '#40E0FF',
  amber: '#F5A623',
  gold: '#FFD700',
  green: '#10B981',
  gray: '#8888a0',
  chrome: '#F8F7F3',
  canvas: '#EEEBE5',
  recessed: '#E3DCD1',
};

const ink = (a: number) => `rgba(17,17,17,${a})`;

// ─── Mock Data ──────────────────────────────────────────────

const CONTACTS = [
  'Leo', 'Kai', 'Ava', 'Zoe', 'Sam', 'Maya',
  'Jordan', 'Priya', 'Alex', 'Nina', 'Ravi', 'Ella',
  'Dev', 'Mika', 'Tara', 'Omar',
].map((name) => ({ id: name.toLowerCase(), name, letter: name[0] }));

const PALETTE = [
  '#E8590C', '#D97706', '#059669', '#0891B2', '#7C3AED',
  '#DB2777', '#DC2626', '#2563EB', '#4F46E5', '#0D9488',
  '#B45309', '#6D28D9', '#0E7490', '#9333EA', '#C2410C', '#1D4ED8',
];

// ─── Shared Components ─────────────────────────────────────

function XAvatar({ name, size = 40, colorIndex = 0 }: {
  name: string; size?: number; colorIndex?: number;
}) {
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: PALETTE[colorIndex % PALETTE.length],
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      color: 'white', fontSize: size * 0.38, fontWeight: 300,
      letterSpacing: '0.02em', flexShrink: 0,
    }}>
      {name[0]}
    </div>
  );
}

function Section({ id, label, title, children, dark = false }: {
  id: string; label: string; title: string; children: React.ReactNode; dark?: boolean;
}) {
  return (
    <section id={id} style={{
      minHeight: '100dvh',
      display: 'flex', flexDirection: 'column',
      justifyContent: 'center', alignItems: 'center',
      padding: '80px 24px',
      background: dark ? '#0A0A0F' : 'transparent',
    }}>
      <div style={{
        fontSize: 11, fontWeight: 300, letterSpacing: '0.2em',
        textTransform: 'uppercase' as const, color: T.accent, marginBottom: 12,
      }}>
        {label}
      </div>
      <div style={{
        fontSize: 24, fontWeight: 300, color: dark ? 'rgba(232,230,225,0.85)' : ink(0.85),
        marginBottom: 48, textAlign: 'center' as const, maxWidth: 400, lineHeight: 1.3,
      }}>
        {title}
      </div>
      <div style={{
        width: '100%', maxWidth: 480,
        display: 'flex', justifyContent: 'center', alignItems: 'center',
        flexDirection: 'column',
      }}>
        {children}
      </div>
    </section>
  );
}

// ─── 1. Contact Globe ───────────────────────────────────────

function ContactGlobe() {
  const containerSize = 340;
  const sphereRadius = 140;
  const [, forceRender] = useState(0);
  const isDragging = useRef(false);
  const rotRef = useRef({ x: 15, y: 15 });
  const velRef = useRef({ x: 0, y: 0.3 });
  const lastPos = useRef({ x: 0, y: 0 });
  const frameRef = useRef<number>(0);
  const [hoveredIdx, setHoveredIdx] = useState<number | null>(null);

  const positions = useMemo(() => {
    const golden = (1 + Math.sqrt(5)) / 2;
    const angleInc = (2 * Math.PI) / golden;
    return CONTACTS.map((_, i) => {
      const t = i / CONTACTS.length;
      const phi = Math.acos(1 - 2 * t);
      const theta = angleInc * i;
      return {
        theta: ((theta * 180) / Math.PI) % 360,
        phi: 15 + ((phi * 180) / Math.PI / 180) * 150,
      };
    });
  }, []);

  useEffect(() => {
    const tick = () => {
      if (!isDragging.current) {
        velRef.current.x *= 0.96;
        velRef.current.y *= 0.96;
        if (Math.abs(velRef.current.y) < 0.15) {
          velRef.current.y = 0.15;
        }
      }
      rotRef.current.x += velRef.current.x;
      rotRef.current.y += velRef.current.y;
      forceRender((n) => n + 1);
      frameRef.current = requestAnimationFrame(tick);
    };
    frameRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frameRef.current);
  }, []);

  const toRad = (d: number) => (d * Math.PI) / 180;
  const rot = rotRef.current;

  const worldPositions = positions.map((pos) => {
    const tR = toRad(pos.theta);
    const pR = toRad(pos.phi);
    const rX = toRad(rot.x);
    const rY = toRad(rot.y);

    let x = sphereRadius * Math.sin(pR) * Math.cos(tR);
    let y = sphereRadius * Math.cos(pR);
    let z = sphereRadius * Math.sin(pR) * Math.sin(tR);

    const x1 = x * Math.cos(rY) + z * Math.sin(rY);
    const z1 = -x * Math.sin(rY) + z * Math.cos(rY);
    x = x1;
    z = z1;

    const y2 = y * Math.cos(rX) - z * Math.sin(rX);
    const z2 = y * Math.sin(rX) + z * Math.cos(rX);
    y = y2;
    z = z2;

    const depth = (z + sphereRadius) / (2 * sphereRadius);
    const scale = 0.5 + depth * 0.5;
    const opacity =
      z < -sphereRadius * 0.2
        ? Math.max(0, (z + sphereRadius * 0.2) / (sphereRadius * 0.8))
        : 1;

    return { x, y, z, scale, opacity, zIndex: Math.round(1000 + z) };
  });

  const handlePointerDown = (e: React.PointerEvent) => {
    isDragging.current = true;
    velRef.current = { x: 0, y: 0 };
    lastPos.current = { x: e.clientX, y: e.clientY };
    e.currentTarget.setPointerCapture(e.pointerId);
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!isDragging.current) return;
    const dx = e.clientX - lastPos.current.x;
    const dy = e.clientY - lastPos.current.y;
    velRef.current = { x: -dy * 0.4, y: dx * 0.4 };
    rotRef.current.x += velRef.current.x;
    rotRef.current.y += velRef.current.y;
    lastPos.current = { x: e.clientX, y: e.clientY };
  };

  const handlePointerUp = () => {
    isDragging.current = false;
  };

  return (
    <div
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerUp}
      style={{
        width: containerSize, height: containerSize,
        position: 'relative',
        cursor: isDragging.current ? 'grabbing' : 'grab',
        touchAction: 'none', userSelect: 'none',
      }}
    >
      {CONTACTS.map((contact, i) => {
        const wp = worldPositions[i];
        if (wp.opacity < 0.05) return null;
        const isHovered = hoveredIdx === i;
        const size = (isHovered ? 48 : 40) * wp.scale;
        return (
          <div
            key={contact.id}
            onPointerEnter={() => setHoveredIdx(i)}
            onPointerLeave={() => setHoveredIdx(null)}
            style={{
              position: 'absolute',
              left: containerSize / 2 + wp.x - size / 2,
              top: containerSize / 2 + wp.y - size / 2,
              width: size, height: size,
              borderRadius: '50%',
              background: PALETTE[i % PALETTE.length],
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: `rgba(255,255,255,${wp.opacity})`,
              fontSize: size * 0.38, fontWeight: 300,
              zIndex: isHovered ? 9999 : wp.zIndex,
              opacity: wp.opacity,
              transition: 'width 0.2s, height 0.2s, font-size 0.2s',
              pointerEvents: wp.opacity > 0.3 ? 'auto' : 'none',
              cursor: 'pointer',
            }}
          >
            {contact.letter}
            {isHovered && wp.opacity > 0.5 && (
              <div style={{
                position: 'absolute', bottom: '110%', left: '50%',
                transform: 'translateX(-50%)',
                background: ink(0.85), color: 'white',
                padding: '4px 10px', borderRadius: 6,
                fontSize: 11, fontWeight: 300,
                whiteSpace: 'nowrap',
                pointerEvents: 'none',
              }}>
                {contact.name}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ─── 2. Text Scramble ───────────────────────────────────────

function TextScramble({ text, trigger }: { text: string; trigger: number }) {
  const [display, setDisplay] = useState('');
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789!@#$%&*';

  useEffect(() => {
    let frame = 0;
    const totalFrames = text.length * 3;
    const interval = setInterval(() => {
      const resolved = Math.floor(frame / 3);
      let result = '';
      for (let i = 0; i < text.length; i++) {
        if (text[i] === ' ') result += ' ';
        else if (i < resolved) result += text[i];
        else result += chars[Math.floor(Math.random() * chars.length)];
      }
      setDisplay(result);
      frame++;
      if (frame > totalFrames) {
        setDisplay(text);
        clearInterval(interval);
      }
    }, 30);
    return () => clearInterval(interval);
  }, [text, trigger]);

  return <span>{display}</span>;
}

// ─── 3. Shimmer Text ────────────────────────────────────────

function ShimmerText({ text }: { text: string }) {
  return (
    <span
      className="shimmer-text-anim"
      style={{
        background: `linear-gradient(90deg, ${ink(0.4)} 0%, ${ink(0.4)} 35%, ${T.cyan} 50%, ${ink(0.4)} 65%, ${ink(0.4)} 100%)`,
        backgroundSize: '200% 100%',
        WebkitBackgroundClip: 'text',
        WebkitTextFillColor: 'transparent',
        fontSize: 18, fontWeight: 300,
        letterSpacing: '0.04em',
      }}
    >
      {text}
    </span>
  );
}

// ─── 4. Typewriter Text ─────────────────────────────────────

function TypewriterText({ texts, speed = 80 }: { texts: string[]; speed?: number }) {
  const [st, setSt] = useState({ ti: 0, ci: 0, del: false, paused: false });

  useEffect(() => {
    const current = texts[st.ti];
    if (st.paused) {
      const t = setTimeout(() => setSt((s) => ({ ...s, paused: false, del: true })), 1500);
      return () => clearTimeout(t);
    }
    const t = setTimeout(() => {
      if (!st.del) {
        if (st.ci < current.length) setSt((s) => ({ ...s, ci: s.ci + 1 }));
        else setSt((s) => ({ ...s, paused: true }));
      } else {
        if (st.ci > 0) setSt((s) => ({ ...s, ci: s.ci - 1 }));
        else setSt((s) => ({ ...s, del: false, ti: (s.ti + 1) % texts.length }));
      }
    }, st.del ? speed / 2 : speed);
    return () => clearTimeout(t);
  }, [st, texts, speed]);

  return (
    <span>
      {texts[st.ti].slice(0, st.ci)}
      <span className="cursor-blink" style={{
        borderRight: `2px solid ${T.cyan}`, marginLeft: 1, paddingRight: 2,
      }} />
    </span>
  );
}

// ─── 5. Slide to Confirm ────────────────────────────────────

function SlideToConfirm() {
  const [completed, setCompleted] = useState(false);
  const x = useMotionValue(0);
  const trackWidth = 300;
  const thumbSize = 52;
  const maxDrag = trackWidth - thumbSize - 8;

  const bgOpacity = useTransform(x, [0, maxDrag], [0, 0.9]);
  const textOpacity = useTransform(x, [0, maxDrag * 0.4], [1, 0]);
  const checkScale = useTransform(x, [maxDrag * 0.7, maxDrag], [0, 1]);

  const handleDragEnd = () => {
    if (x.get() > maxDrag * 0.85) {
      setCompleted(true);
    } else {
      animate(x, 0, { type: 'spring', stiffness: 400, damping: 30 });
    }
  };

  if (completed) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16 }}>
        <motion.div
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          style={{
            width: trackWidth, height: 56, borderRadius: 28,
            background: T.green,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: 'white', fontSize: 15, fontWeight: 300,
            letterSpacing: '0.06em',
          }}
        >
          purchase confirmed
        </motion.div>
        <button
          onClick={() => { setCompleted(false); x.set(0); }}
          style={{
            background: 'transparent', border: 'none', color: ink(0.3),
            fontSize: 12, fontWeight: 300, cursor: 'pointer', letterSpacing: '0.08em',
          }}
        >
          reset
        </button>
      </div>
    );
  }

  return (
    <div style={{
      width: trackWidth, height: 56, borderRadius: 28,
      background: T.recessed, position: 'relative', overflow: 'hidden',
    }}>
      <motion.div style={{
        position: 'absolute', inset: 0, borderRadius: 28,
        background: T.green, opacity: bgOpacity,
      }} />
      <motion.div style={{
        position: 'absolute', inset: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: ink(0.35), fontSize: 13, fontWeight: 300,
        letterSpacing: '0.08em', opacity: textOpacity,
        pointerEvents: 'none',
      }}>
        slide to confirm purchase
      </motion.div>
      <motion.div style={{
        position: 'absolute', right: 16, top: '50%', y: '-50%',
        color: 'white', fontSize: 18, fontWeight: 300,
        opacity: checkScale, scale: checkScale,
        pointerEvents: 'none',
      }}>
        ✓
      </motion.div>
      <motion.div
        drag="x"
        dragConstraints={{ left: 0, right: maxDrag }}
        dragElastic={0}
        dragMomentum={false}
        onDragEnd={handleDragEnd}
        style={{
          x,
          width: thumbSize, height: thumbSize - 8,
          borderRadius: 24, background: T.accent,
          position: 'absolute', top: 4, left: 4,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'grab', zIndex: 2,
          color: 'white', fontSize: 16, fontWeight: 300,
        }}
      >
        &#8594;
      </motion.div>
    </div>
  );
}

// ─── 6. Feedback Reactions ──────────────────────────────────

function FeedbackReaction() {
  const [selected, setSelected] = useState<string | null>(null);

  const options = [
    { id: 'love', label: 'love it', icon: '♥', color: T.amber, weight: '+5' },
    { id: 'works', label: 'works for me', icon: '●', color: T.gray, weight: '+1' },
    { id: 'not', label: 'not for me', icon: '—', color: T.accent, weight: '-3' },
  ];

  return (
    <div style={{ display: 'flex', gap: 12, alignItems: 'stretch' }}>
      {options.map((opt) => {
        const isSelected = selected === opt.id;
        return (
          <motion.button
            key={opt.id}
            onClick={() => setSelected(isSelected ? null : opt.id)}
            whileTap={{ scale: 0.92 }}
            animate={{
              scale: isSelected ? 1.08 : 1,
              opacity: selected && !isSelected ? 0.3 : 1,
            }}
            transition={{ type: 'spring', stiffness: 400, damping: 22 }}
            style={{
              background: isSelected ? opt.color : T.canvas,
              color: isSelected ? 'white' : ink(0.5),
              border: 'none', borderRadius: 20,
              padding: '14px 20px',
              fontSize: 13, fontWeight: 300,
              letterSpacing: '0.06em',
              cursor: 'pointer',
              display: 'flex', flexDirection: 'column',
              alignItems: 'center', gap: 8,
              minWidth: 100,
            }}
          >
            <motion.span
              animate={{ scale: isSelected ? 1.3 : 1 }}
              style={{ fontSize: 22, lineHeight: 1 }}
            >
              {opt.icon}
            </motion.span>
            <span>{opt.label}</span>
            <AnimatePresence>
              {isSelected && (
                <motion.span
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 0.7, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  style={{ fontSize: 11, fontWeight: 300 }}
                >
                  {opt.weight}
                </motion.span>
              )}
            </AnimatePresence>
          </motion.button>
        );
      })}
    </div>
  );
}

// ─── 7. Animated Avatar Tooltips ────────────────────────────

function AnimatedTooltipAvatars() {
  const [hovered, setHovered] = useState<number | null>(null);
  const people = CONTACTS.slice(0, 6);

  return (
    <div style={{ display: 'flex', alignItems: 'center', padding: '40px 0' }}>
      {people.map((person, i) => (
        <div
          key={person.id}
          style={{
            marginLeft: i > 0 ? -10 : 0,
            position: 'relative',
            zIndex: hovered === i ? 20 : 10 - i,
          }}
          onMouseEnter={() => setHovered(i)}
          onMouseLeave={() => setHovered(null)}
        >
          <AnimatePresence>
            {hovered === i && (
              <motion.div
                initial={{ opacity: 0, y: 8, scale: 0.7, rotate: -8 }}
                animate={{ opacity: 1, y: -10, scale: 1, rotate: 0 }}
                exit={{ opacity: 0, y: 8, scale: 0.7 }}
                transition={{ type: 'spring', stiffness: 350, damping: 18 }}
                style={{
                  position: 'absolute', bottom: '100%', left: '50%',
                  transform: 'translateX(-50%)',
                  background: ink(0.88), color: 'white',
                  padding: '5px 12px', borderRadius: 8,
                  fontSize: 12, fontWeight: 300,
                  whiteSpace: 'nowrap',
                  pointerEvents: 'none',
                  letterSpacing: '0.03em',
                }}
              >
                {person.name}
                <div style={{
                  position: 'absolute', top: '100%', left: '50%',
                  marginLeft: -4,
                  width: 0, height: 0,
                  borderLeft: '4px solid transparent',
                  borderRight: '4px solid transparent',
                  borderTop: `4px solid ${ink(0.88)}`,
                }} />
              </motion.div>
            )}
          </AnimatePresence>
          <motion.div
            whileHover={{ scale: 1.2, y: -6 }}
            transition={{ type: 'spring', stiffness: 400, damping: 18 }}
            style={{ cursor: 'pointer' }}
          >
            <XAvatar name={person.name} size={48} colorIndex={i} />
          </motion.div>
        </div>
      ))}
    </div>
  );
}

// ─── 8. Member Selector ─────────────────────────────────────

function MemberSelector() {
  const [selected, setSelected] = useState<string[]>(['leo', 'ava', 'priya']);
  const [isOpen, setIsOpen] = useState(false);
  const [search, setSearch] = useState('');

  const filtered = CONTACTS.filter((c) =>
    c.name.toLowerCase().includes(search.toLowerCase())
  );

  const toggle = (id: string) => {
    setSelected((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]
    );
  };

  return (
    <div style={{ width: '100%', maxWidth: 360 }}>
      <div style={{
        display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 16,
        alignItems: 'center',
      }}>
        <AnimatePresence mode="popLayout">
          {selected.map((id) => {
            const c = CONTACTS.find((x) => x.id === id);
            if (!c) return null;
            const idx = CONTACTS.indexOf(c);
            return (
              <motion.div
                key={id}
                initial={{ scale: 0, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                exit={{ scale: 0, opacity: 0 }}
                layout
                style={{
                  display: 'flex', alignItems: 'center', gap: 8,
                  background: T.canvas, borderRadius: 20,
                  padding: '4px 12px 4px 4px',
                }}
              >
                <XAvatar name={c.name} size={26} colorIndex={idx} />
                <span style={{ fontSize: 13, fontWeight: 300, color: ink(0.65) }}>
                  {c.name}
                </span>
                <span
                  onClick={() => toggle(id)}
                  style={{
                    cursor: 'pointer', color: ink(0.3), fontSize: 15,
                    marginLeft: 2, lineHeight: 1,
                  }}
                >
                  ×
                </span>
              </motion.div>
            );
          })}
        </AnimatePresence>
        <motion.button
          whileHover={{ scale: 1.08 }}
          whileTap={{ scale: 0.95 }}
          onClick={() => setIsOpen(!isOpen)}
          style={{
            width: 34, height: 34, borderRadius: '50%',
            border: `1.5px dashed ${ink(0.18)}`,
            background: 'transparent', cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: ink(0.35), fontSize: 18, fontWeight: 300,
          }}
        >
          +
        </motion.button>
      </div>

      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ type: 'spring', stiffness: 400, damping: 28 }}
          >
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="search people..."
              autoFocus
              style={{
                width: '100%', padding: '10px 16px', boxSizing: 'border-box',
                background: T.canvas, border: 'none',
                borderRadius: 12, fontSize: 14, fontWeight: 300,
                color: ink(0.8), outline: 'none', marginBottom: 8,
              }}
            />
            <div style={{ maxHeight: 220, overflowY: 'auto' }}>
              {filtered.map((c) => {
                const idx = CONTACTS.indexOf(c);
                const isSel = selected.includes(c.id);
                return (
                  <motion.div
                    key={c.id}
                    whileHover={{ background: T.canvas }}
                    onClick={() => toggle(c.id)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 12,
                      padding: '8px 12px', cursor: 'pointer', borderRadius: 8,
                      background: 'transparent',
                    }}
                  >
                    <XAvatar name={c.name} size={32} colorIndex={idx} />
                    <span style={{
                      fontSize: 14, fontWeight: 300,
                      color: isSel ? ink(0.9) : ink(0.55), flex: 1,
                    }}>
                      {c.name}
                    </span>
                    {isSel && (
                      <motion.span
                        initial={{ scale: 0 }}
                        animate={{ scale: 1 }}
                        style={{ color: T.green, fontSize: 16 }}
                      >
                        ✓
                      </motion.span>
                    )}
                  </motion.div>
                );
              })}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// ─── 9. Quick Tooltip Actions ───────────────────────────────

function QuickTooltipActions() {
  const [hovered, setHovered] = useState(false);
  const actions = [
    { icon: '💬', label: 'chat' },
    { icon: '👤', label: 'profile' },
    { icon: '🔕', label: 'mute' },
  ];

  return (
    <div
      style={{ position: 'relative', display: 'inline-block' }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <motion.div
        whileHover={{ scale: 1.05 }}
        style={{ cursor: 'pointer' }}
      >
        <XAvatar name="Leo" size={52} colorIndex={0} />
      </motion.div>
      <AnimatePresence>
        {hovered && (
          <motion.div
            initial={{ opacity: 0, scale: 0.7, y: 4 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.7, y: 4 }}
            transition={{ type: 'spring', stiffness: 500, damping: 25 }}
            style={{
              position: 'absolute', top: '110%', left: '50%',
              transform: 'translateX(-50%)',
              display: 'flex', gap: 2,
              background: ink(0.9), borderRadius: 14,
              padding: '6px 8px',
            }}
          >
            {actions.map((action, i) => (
              <motion.button
                key={i}
                whileHover={{ scale: 1.2, background: 'rgba(255,255,255,0.1)' }}
                whileTap={{ scale: 0.9 }}
                style={{
                  width: 36, height: 36, borderRadius: 10,
                  border: 'none', background: 'transparent',
                  cursor: 'pointer', fontSize: 16,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}
                title={action.label}
              >
                {action.icon}
              </motion.button>
            ))}
          </motion.div>
        )}
      </AnimatePresence>
      <div style={{
        textAlign: 'center', marginTop: 8,
        fontSize: 12, fontWeight: 300, color: ink(0.4),
        letterSpacing: '0.04em',
      }}>
        hover me
      </div>
    </div>
  );
}

// ─── 10. Fluid Menu ─────────────────────────────────────────

function FluidMenu() {
  const [isOpen, setIsOpen] = useState(false);
  const items = [
    { icon: '🏠', label: 'spaces' },
    { icon: '💬', label: 'chats' },
    { icon: '🔍', label: 'search' },
    { icon: '⚙️', label: 'settings' },
  ];

  return (
    <div style={{
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', gap: 8,
    }}>
      <AnimatePresence>
        {isOpen &&
          items.map((item, i) => (
            <motion.button
              key={item.label}
              initial={{ opacity: 0, scale: 0.3, y: 30 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.3, y: 30 }}
              transition={{
                type: 'spring', stiffness: 400, damping: 22,
                delay: i * 0.06,
              }}
              whileHover={{ scale: 1.12 }}
              whileTap={{ scale: 0.9 }}
              style={{
                width: 48, height: 48, borderRadius: '50%',
                border: 'none', background: T.canvas,
                cursor: 'pointer', fontSize: 20,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                position: 'relative',
              }}
            >
              {item.icon}
              <span style={{
                position: 'absolute', left: '120%',
                fontSize: 12, fontWeight: 300, color: ink(0.4),
                whiteSpace: 'nowrap', letterSpacing: '0.06em',
              }}>
                {item.label}
              </span>
            </motion.button>
          ))}
      </AnimatePresence>
      <motion.button
        whileTap={{ scale: 0.9 }}
        onClick={() => setIsOpen(!isOpen)}
        animate={{ rotate: isOpen ? 135 : 0 }}
        transition={{ type: 'spring', stiffness: 400, damping: 22 }}
        style={{
          width: 56, height: 56, borderRadius: '50%',
          border: 'none', background: T.accent,
          cursor: 'pointer', fontSize: 28, color: 'white',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontWeight: 300,
        }}
      >
        +
      </motion.button>
    </div>
  );
}

// ─── Page ───────────────────────────────────────────────────

const SECTIONS = [
  { id: 'globe', label: 'globe' },
  { id: 'scramble', label: 'scramble' },
  { id: 'shimmer', label: 'shimmer' },
  { id: 'typewriter', label: 'typewriter' },
  { id: 'slide', label: 'slide' },
  { id: 'reactions', label: 'reactions' },
  { id: 'tooltips', label: 'tooltips' },
  { id: 'selector', label: 'selector' },
  { id: 'actions', label: 'actions' },
  { id: 'menu', label: 'menu' },
];

export default function PrototypePage() {
  const [scrambleTrigger, setScrambleTrigger] = useState(0);

  return (
    <>
      <style>{`
        html { scroll-behavior: smooth; }
        body { margin: 0; }
        .cursor-blink { animation: cblink 1s step-end infinite; }
        @keyframes cblink { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }
        .shimmer-text-anim { animation: shimslide 2.5s ease-in-out infinite; }
        @keyframes shimslide { 0% { background-position: -200% center; } 100% { background-position: 200% center; } }
        ::-webkit-scrollbar { width: 0; }
      `}</style>

      <div style={{
        background: T.void,
        color: ink(0.8),
        fontFamily: 'Inter, system-ui, sans-serif',
        minHeight: '100dvh',
        position: 'relative',
      }}>
        {/* Fixed Header */}
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, zIndex: 100,
          padding: '20px 24px',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          background: `linear-gradient(180deg, ${T.void} 60%, transparent)`,
        }}>
          <span style={{
            fontSize: 18, fontWeight: 300, letterSpacing: '0.2em', color: T.accent,
          }}>
            xark
          </span>
          <span style={{
            fontSize: 11, fontWeight: 300, color: ink(0.3),
            letterSpacing: '0.12em', textTransform: 'uppercase' as const,
          }}>
            component lab
          </span>
        </div>

        {/* Fixed Nav Dots */}
        <div style={{
          position: 'fixed', right: 16, top: '50%', transform: 'translateY(-50%)',
          display: 'flex', flexDirection: 'column', gap: 12, zIndex: 100,
        }}>
          {SECTIONS.map((s) => (
            <a
              key={s.id}
              href={`#${s.id}`}
              title={s.label}
              style={{
                width: 6, height: 6, borderRadius: '50%',
                background: ink(0.15), display: 'block',
                transition: 'background 0.2s, transform 0.2s',
              }}
              onMouseEnter={(e) => {
                (e.target as HTMLElement).style.background = T.accent;
                (e.target as HTMLElement).style.transform = 'scale(1.5)';
              }}
              onMouseLeave={(e) => {
                (e.target as HTMLElement).style.background = ink(0.15);
                (e.target as HTMLElement).style.transform = 'scale(1)';
              }}
            />
          ))}
        </div>

        {/* 1. Contact Globe */}
        <Section id="globe" label="about screen" title="your universe">
          <ContactGlobe />
          <div style={{
            marginTop: 24, fontSize: 12, fontWeight: 300,
            color: ink(0.3), letterSpacing: '0.06em', textAlign: 'center',
          }}>
            drag to spin · momentum physics · tap contact to chat
          </div>
        </Section>

        {/* 2. Text Scramble */}
        <Section id="scramble" label="@xark response" title="message reveal">
          <div style={{ textAlign: 'center' }}>
            <div style={{
              fontSize: 17, fontWeight: 300, color: T.cyan,
              marginBottom: 24, letterSpacing: '0.01em', lineHeight: 1.5,
            }}>
              <TextScramble
                text="found 3 spots near downtown, all under $40"
                trigger={scrambleTrigger}
              />
            </div>
            <button
              onClick={() => setScrambleTrigger((t) => t + 1)}
              style={{
                background: 'transparent', border: 'none',
                color: ink(0.3), fontSize: 12, fontWeight: 300,
                cursor: 'pointer', letterSpacing: '0.1em',
              }}
            >
              tap to replay
            </button>
          </div>
        </Section>

        {/* 3. Shimmer Text */}
        <Section id="shimmer" label="@xark thinking" title="shimmer state">
          <ShimmerText text="xark is thinking..." />
        </Section>

        {/* 4. Typewriter */}
        <Section id="typewriter" label="onboarding" title="typewriter whispers">
          <div style={{ fontSize: 17, fontWeight: 300, color: ink(0.5) }}>
            <TypewriterText
              texts={[
                'what are we deciding?',
                'where should we eat tonight?',
                'plan something together',
                'who is booking the hotel?',
              ]}
            />
          </div>
        </Section>

        {/* 5. Slide to Confirm */}
        <Section id="slide" label="purchase sheet" title="slide to confirm">
          <SlideToConfirm />
        </Section>

        {/* 6. Feedback Reactions */}
        <Section id="reactions" label="signal system" title="reaction feedback">
          <FeedbackReaction />
        </Section>

        {/* 7. Animated Tooltips */}
        <Section id="tooltips" label="member presence" title="avatar tooltips">
          <AnimatedTooltipAvatars />
        </Section>

        {/* 8. Member Selector */}
        <Section id="selector" label="invite flow" title="member selector">
          <MemberSelector />
        </Section>

        {/* 9. Quick Tooltip Actions */}
        <Section id="actions" label="chat avatar" title="quick actions">
          <div style={{ padding: 60 }}>
            <QuickTooltipActions />
          </div>
        </Section>

        {/* 10. Fluid Menu */}
        <Section id="menu" label="control caret" title="fluid menu">
          <FluidMenu />
        </Section>

        {/* Footer */}
        <div style={{
          padding: '48px 24px', textAlign: 'center',
          fontSize: 11, fontWeight: 300, color: ink(0.2),
          letterSpacing: '0.15em',
        }}>
          xark os · component prototypes · 2026
        </div>
      </div>
    </>
  );
}
