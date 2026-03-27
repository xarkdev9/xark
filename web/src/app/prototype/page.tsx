'use client';
import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import SphereImageGrid, { SphereNode } from '@/components/os/SphereImageGrid';
import DecisionBoard from '@/components/os/DecisionBoard';

const UNIVERSE_NODES: SphereNode[] = [
  { id: 'cat-1', type: 'category', label: 'hotels' },
  { id: 'cat-2', type: 'category', label: 'flights' },
  { id: 'cat-3', type: 'category', label: 'up for grabs' },
  { id: 'cat-4', type: 'category', label: 'active polls' },
  { id: 'cat-5', type: 'category', label: 'the vault: claimed tasks' }, // Exact string match for DB grouping
];

export default function PrototypePage() {
  const [activeHub, setActiveHub] = useState<string | null>(null);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768);
    checkMobile(); // Run once on mount
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  const config = isMobile 
    ? { container: 400, radius: 160, scale: 0.25 }
    : { container: 800, radius: 340, scale: 0.16 };

  return (
    <div className="min-h-svh bg-[#08080C] relative overflow-hidden font-sans">
      <AnimatePresence mode="wait">
        {activeHub ? (
          <motion.div 
            key="horizon"
            initial={{ opacity: 0, scale: 0.95, filter: "blur(10px)" }}
            animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
            exit={{ opacity: 0, scale: 1.05, filter: "blur(10px)" }}
            transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
            className="absolute inset-0 z-10 bg-[#08080C]"
          >
            <div className="fixed top-0 left-0 right-0 z-[200] p-6 lg:p-10 flex justify-between items-center bg-gradient-to-b from-[#08080C]/80 to-transparent pointer-events-none">
              <button 
                onClick={() => setActiveHub(null)}
                className="flex items-center gap-2 text-[#A1A1A6] hover:text-white transition-colors cursor-pointer bg-white/5 px-5 py-3 rounded-full backdrop-blur-xl border border-white/10 pointer-events-auto shadow-2xl"
              >
                 <span className="text-lg leading-none mb-0.5">←</span> 
                 <span className="uppercase tracking-widest text-[11px] font-medium">Return to Universe</span>
              </button>
            </div>
            
            {/* The Horizon mounts and exclusively filters to the selected category */}
            <div className="h-full overflow-y-auto">
               <DecisionBoard groupId="pg_tokyo-neon-nights" filterCategory={activeHub} />
            </div>
          </motion.div>
        ) : (
          <motion.div 
            key="sphere"
            initial={{ opacity: 0, scale: 1.1, filter: "blur(10px)" }}
            animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
            exit={{ opacity: 0, scale: 0.9, filter: "blur(10px)" }}
            transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
            className="absolute inset-0 z-10 flex flex-col items-center justify-center"
          >
            <div className="absolute top-12 left-10 lg:left-16 z-50 pointer-events-none">
              <motion.div initial={{ y: -20, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: 0.3, duration: 0.8 }}>
                <h1 className="text-4xl lg:text-5xl font-light text-white tracking-tight mb-3">Tokyo Neon Nights</h1>
                <div className="flex items-center gap-3">
                  <div className="w-2 h-2 rounded-full bg-[#FF6B35] shadow-[0_0_12px_#FF6B35]" />
                  <p className="text-[#A1A1A6] font-light text-[11px] tracking-[0.2em] uppercase">The Universe View</p>
                </div>
              </motion.div>
            </div>

            <div className="absolute inset-0 pointer-events-none" style={{ background: 'radial-gradient(circle at 50% 50%, transparent 20%, #08080C 100%)', zIndex: 0 }} />
            
            <SphereImageGrid 
              items={UNIVERSE_NODES}
              containerSize={config.container}
              sphereRadius={config.radius}
              autoRotate={true}
              autoRotateSpeed={0.12}
              baseItemScale={config.scale}
              onNodeClick={(node) => setActiveHub(node.label)}
              className="z-10"
            />
            
            <div className="absolute bottom-12 text-center z-50 pointer-events-none">
              <p className="text-[#A1A1A6]/50 font-light text-[10px] tracking-[0.3em] uppercase mb-1">Interactive Compass</p>
              <p className="text-white/30 font-light text-[11px] tracking-widest">Drag to spin · Tap category to enter</p>
            </div>

          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
