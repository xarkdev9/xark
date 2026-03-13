"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { fetchSettlement, generateVenmoLink, generateUPILink } from "@/lib/ledger";
import type { Settlement } from "@/lib/ledger";
import { ConsensusMark } from "./ConsensusMark";

import { colors, opacity } from "@/lib/theme";

interface LockedItem {
  id: string;
  title: string;
  category: string;
  description: string;
  state: string;
  weighted_score: number;
  ownership: { ownerId: string } | null;
  commitment_proof: {
    type: string;
    value: string;
    submittedBy: string;
    submittedAt: string;
  } | null;
  locked_at: string | null;
}

interface BlueprintProps {
  spaceId: string;
}

export function Blueprint({ spaceId }: BlueprintProps) {
  const [items, setItems] = useState<LockedItem[]>([]);
  const [settlement, setSettlement] = useState<Settlement | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchLocked() {
      const { data, error } = await supabase
        .from("decision_items")
        .select(
          "id, title, category, description, state, weighted_score, ownership, commitment_proof, locked_at"
        )
        .eq("space_id", spaceId)
        .eq("is_locked", true)
        .order("locked_at", { ascending: true });

      if (!error && data) {
        setItems(data as LockedItem[]);
      }

      // Fetch settlement data
      const settleData = await fetchSettlement(spaceId);
      if (settleData.entries.length > 0) {
        setSettlement(settleData);
      }

      setLoading(false);
    }

    fetchLocked();
  }, [spaceId]);

  function formatDate(iso: string | null): string {
    if (!iso) return "";
    return new Date(iso).toLocaleDateString(undefined, {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  }

  if (loading) {
    return (
      <div
        className="flex items-center justify-center pt-32"
        style={{ opacity: 0.2 }}
      >
        <div
          style={{
            width: "6px",
            height: "6px",
            borderRadius: "50%",
            backgroundColor: colors.cyan,
            animation: "ambientBreath 4.5s ease-in-out infinite",
          }}
        />
      </div>
    );
  }

  return (
    <div className="min-h-svh px-6 pt-16 pb-24">
      {/* ── Header ── */}
      <div className="mx-auto" style={{ maxWidth: "640px" }}>
        <h1
          style={{
            fontSize: "32px",
            color: colors.white,
            opacity: 0.9,
            lineHeight: 1.2,
            letterSpacing: "-0.02em",
          }}
        >
          the blueprint.
        </h1>
        <p
          className="mt-2"
          style={{
            fontSize: "0.875rem",
            color: colors.white,
            opacity: 0.4,
            letterSpacing: "0.04em",
          }}
        >
          every decision that became real
        </p>
      </div>

      {/* ── Empty state ── */}
      {items.length === 0 && (
        <div
          className="mx-auto mt-24 text-center"
          style={{ maxWidth: "640px", opacity: 0.2 }}
        >
          <p
            style={{
              fontSize: "0.7rem",
              letterSpacing: "0.2em",
              textTransform: "uppercase",
              color: colors.white,
            }}
          >
            no locked decisions yet
          </p>
        </div>
      )}

      {/* ── Timeline stream ── */}
      {items.length > 0 && (
        <div className="relative mx-auto mt-16" style={{ maxWidth: "640px" }}>
          {/* ── 1px vertical timeline — atmospheric anchor, NOT a border ── */}
          <div
            className="absolute top-0 left-4 h-full"
            style={{
              width: "1px",
              backgroundColor: colors.white,
              opacity: 0.1,
            }}
          />

          {items.map((item, index) => (
            <motion.div
              key={item.id}
              className="relative pl-12 pb-16"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{
                duration: 0.6,
                delay: index * 0.1,
                ease: "easeOut",
              }}
            >
              {/* ── Timeline node — finality wash ── */}
              <div
                className="absolute left-2 top-1"
                style={{
                  width: "5px",
                  height: "5px",
                  borderRadius: "50%",
                  backgroundColor: colors.white,
                  opacity: 0.3,
                }}
              />

              {/* ── Category label ── */}
              <span
                style={{
                  fontSize: "10px",
                  letterSpacing: "0.2em",
                  textTransform: "uppercase",
                  color: colors.white,
                  opacity: 0.3,
                }}
              >
                {item.category}
              </span>

              {/* ── Title — primary hierarchy through scale ── */}
              <p
                className="mt-2 text-xl"
                style={{
                  color: colors.white,
                  opacity: 0.9,
                  lineHeight: 1.4,
                  letterSpacing: "-0.01em",
                }}
              >
                {item.title}
              </p>

              {/* ── Description ── */}
              {item.description && (
                <p
                  className="mt-2 text-sm"
                  style={{
                    color: colors.white,
                    opacity: 0.4,
                    lineHeight: 1.6,
                    letterSpacing: "0.02em",
                  }}
                >
                  {item.description}
                </p>
              )}

              {/* ── Metadata row — commitment proof + timestamp ── */}
              <div className="mt-4 flex items-center gap-4">
                {/* ConsensusMark in ignited state — The Mark of Truth */}
                <ConsensusMark agreementScore={1} state="ignited" size={24} />

                {item.commitment_proof && (
                  <span
                    style={{
                      fontSize: "0.875rem",
                      color: colors.white,
                      opacity: 0.4,
                      letterSpacing: "0.04em",
                    }}
                  >
                    {item.commitment_proof.type === "confirmation_number"
                      ? `#${item.commitment_proof.value}`
                      : item.commitment_proof.type}
                  </span>
                )}

                {item.locked_at && (
                  <span
                    style={{
                      fontSize: "0.55rem",
                      letterSpacing: "0.15em",
                      textTransform: "uppercase",
                      color: colors.white,
                      opacity: 0.25,
                    }}
                  >
                    {formatDate(item.locked_at)}
                  </span>
                )}
              </div>

              {/* ── Finality wash — settled atmospheric glow ── */}
              <div
                className="pointer-events-none absolute inset-0 -z-10"
                style={{
                  background:
                    "radial-gradient(ellipse 100% 80% at 0% 20%, currentColor 0%, transparent 60%)",
                  color: colors.white,
                  opacity: 0.05,
                }}
              />
            </motion.div>
          ))}
        </div>
      )}

      {/* ── Settlement Ledger — The Subtle Settle ── */}
      {settlement && settlement.entries.length > 0 && (
        <motion.div
          className="mx-auto mt-8"
          style={{ maxWidth: "640px" }}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.8, delay: items.length * 0.1 + 0.3 }}
        >
          {/* ── Divider — 1px atmospheric line ── */}
          <div
            style={{
              height: "1px",
              backgroundColor: colors.white,
              opacity: 0.06,
              marginBottom: "32px",
            }}
          />

          {/* ── Settlement entries — who paid what ── */}
          {settlement.entries.map((entry) => {
            const delta = entry.totalPaid - settlement.fairShare;
            const isAhead = delta > 0;
            const absDelta = Math.abs(Math.round(delta * 100) / 100);

            return (
              <div key={entry.userId} className="pb-6">
                <p
                  style={{
                    fontSize: "0.875rem",
                    color: colors.white,
                    opacity: 0.5,
                    lineHeight: 1.6,
                  }}
                >
                  {entry.displayName} {isAhead ? "is ahead" : "owes"}{" "}
                  <span style={{ opacity: 1 }}>${absDelta}</span>
                </p>

                {/* ── Item breakdown ── */}
                {entry.items.map((item) => (
                  <p
                    key={item.title}
                    className="mt-1"
                    style={{
                      fontSize: "0.7rem",
                      letterSpacing: "0.1em",
                      color: colors.white,
                      opacity: 0.25,
                    }}
                  >
                    {item.title} — ${item.amount}
                  </p>
                ))}
              </div>
            );
          })}

          {/* ── Debt Deltas with payment deep links ── */}
          {settlement.deltas.map((delta, i) => (
            <div key={i} className="flex items-center gap-4 pb-4">
              <p
                style={{
                  fontSize: "0.875rem",
                  color: colors.white,
                  opacity: 0.4,
                  lineHeight: 1.6,
                }}
              >
                {delta.fromName} owes {delta.toName} ${delta.amount}
              </p>

              {/* ── Payment deep links — floating text, no boxes ── */}
              <a
                href={generateVenmoLink(
                  delta.toName,
                  delta.amount,
                  `xark settle — group trip`
                )}
                style={{
                  fontSize: "0.6rem",
                  letterSpacing: "0.2em",
                  textTransform: "uppercase" as const,
                  color: colors.cyan,
                  opacity: 0.5,
                  textDecoration: "none",
                  transition: "opacity 0.3s ease",
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.opacity = "0.8";
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.opacity = "0.5";
                }}
              >
                venmo
              </a>

              <a
                href={generateUPILink(
                  `${delta.toName}@upi`,
                  delta.toName,
                  delta.amount,
                  `xark settle — group trip`
                )}
                style={{
                  fontSize: "0.6rem",
                  letterSpacing: "0.2em",
                  textTransform: "uppercase" as const,
                  color: colors.cyan,
                  opacity: 0.5,
                  textDecoration: "none",
                  transition: "opacity 0.3s ease",
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.opacity = "0.8";
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.opacity = "0.5";
                }}
              >
                upi
              </a>
            </div>
          ))}

          {/* ── Total + Fair Share ── */}
          <div className="mt-6">
            <p
              style={{
                fontSize: "0.6rem",
                letterSpacing: "0.2em",
                textTransform: "uppercase" as const,
                color: colors.white,
                opacity: 0.2,
              }}
            >
              total committed — ${settlement.totalSpent}
            </p>
            <p
              className="mt-2"
              style={{
                fontSize: "0.6rem",
                letterSpacing: "0.15em",
                color: colors.white,
                opacity: 0.15,
              }}
            >
              {settlement.memberCount} members — ${Math.round(settlement.fairShare * 100) / 100} per person
            </p>
          </div>
        </motion.div>
      )}
    </div>
  );
}
