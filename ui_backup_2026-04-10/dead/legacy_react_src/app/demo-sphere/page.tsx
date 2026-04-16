'use client';
import SphereImageGrid, { ImageData }  from "@/components/ui/img-sphere";
import React, { useState, useEffect } from 'react';

const BASE_IMAGES: Omit<ImageData, 'id'>[] = [
  {
    src: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=600",
    alt: "Image 1",
    title: "Portrait Photography",
    description: "Professional portrait capture."
  },
  {
    src: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&q=80&w=600",
    alt: "Image 2",
    title: "Cinematic Lighting",
    description: "Dark moody cinematic aesthetic."
  },
  {
    src: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=600",
    alt: "Image 3",
    title: "Fashion Editorial",
    description: "High-contrast editorial lighting."
  },
  {
    src: "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?auto=format&fit=crop&q=80&w=600",
    alt: "Image 4",
    title: "Street Style",
    description: "Urban photography at golden hour."
  },
  {
    src: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=600",
    alt: "Image 5",
    title: "Natural Light",
    description: "Soft scattered daylight capture."
  },
  {
    src: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&q=80&w=600",
    alt: "Image 6",
    title: "Studio Headshot",
    description: "Clean simple backdrop."
  },
  {
    src: "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&q=80&w=600",
    alt: "Image 7",
    title: "Lifestyle",
    description: "Authentic documentary styling."
  },
  {
    src: "https://images.unsplash.com/photo-1488161628813-04466f872442?auto=format&fit=crop&q=80&w=600",
    alt: "Image 8",
    title: "Creative Concept",
    description: "Artistic directional light."
  },
  {
    src: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=600",
    alt: "Image 9",
    title: "Classic Portrait",
    description: "Timeless black and white processing."
  },
  {
    src: "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&q=80&w=600",
    alt: "Image 10",
    title: "Commercial",
    description: "Bright energetic mood."
  }
];

// Generate more images by repeating the base set (like the attached photo shows ~40+ avatars)
const IMAGES: ImageData[] = [];
for (let i = 0; i < 48; i++) {
  const baseIndex = i % BASE_IMAGES.length;
  const baseImage = BASE_IMAGES[baseIndex];
  IMAGES.push({
    id: `img-${i + 1}`,
    ...baseImage,
    alt: `${baseImage.alt} (${Math.floor(i / BASE_IMAGES.length) + 1})`
  });
}

export default function DemoOne() {

  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const handleResize = () => setIsMobile(window.innerWidth < 768);
    handleResize(); // Initial setup
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // Use different config for mobile vs desktop while avoiding hydration mismatches
  const CONFIG = {
    containerSize: isMobile ? 400 : 700,          // Container size in pixels
    sphereRadius: isMobile ? 180 : 300,           // Virtual sphere radius
    dragSensitivity: 0.8,
    momentumDecay: 0.96,
    maxRotationSpeed: 6,
    baseImageScale: isMobile ? 0.22 : 0.16,       // Base image size ratio
    hoverScale: 1.3,
    perspective: 1200,
    autoRotate: true,
    autoRotateSpeed: 0.15
  };

  return (
    <main className="w-full flex justify-center items-center min-h-svh bg-white">
      <SphereImageGrid
        images={IMAGES}
        {...CONFIG}
        className="mx-auto"
      />
    </main>
  );
}
