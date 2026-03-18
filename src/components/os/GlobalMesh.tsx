"use client";

import { motion } from "framer-motion";
import { colors } from "@/lib/theme";

export function GlobalMesh() {
  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        zIndex: -1,
        pointerEvents: "none",
        overflow: "hidden",
      }}
    >
      {/* Cyan breathing orb (AI Intelligence) */}
      <motion.div
        animate={{
          x: ["0%", "-10%", "5%", "0%"],
          y: ["0%", "15%", "-5%", "0%"],
          scale: [1, 1.2, 0.9, 1],
          opacity: [0.08, 0.12, 0.05, 0.08],
        }}
        transition={{
          duration: 25,
          repeat: Infinity,
          ease: "easeInOut",
        }}
        style={{
          position: "absolute",
          top: "10%",
          left: "15%",
          width: "60vw",
          height: "60vw",
          borderRadius: "50%",
          background: `radial-gradient(circle, ${colors.cyan} 0%, transparent 60%)`,
          filter: "blur(60px)",
          transform: "translate3d(0,0,0)",
        }}
      />
      
      {/* Action Orange breathing orb (Human Intent) */}
      <motion.div
        animate={{
          x: ["0%", "10%", "-5%", "0%"],
          y: ["0%", "-15%", "5%", "0%"],
          scale: [1, 0.8, 1.1, 1],
          opacity: [0.05, 0.1, 0.03, 0.05],
        }}
        transition={{
          duration: 30,
          repeat: Infinity,
          ease: "easeInOut",
          delay: 2,
        }}
        style={{
          position: "absolute",
          bottom: "15%",
          right: "10%",
          width: "70vw",
          height: "70vw",
          borderRadius: "50%",
          background: `radial-gradient(circle, ${colors.accent} 0%, transparent 60%)`,
          filter: "blur(80px)",
          transform: "translate3d(0,0,0)",
        }}
      />
    </div>
  );
}
