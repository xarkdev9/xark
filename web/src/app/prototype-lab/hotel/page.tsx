"use client";

// Cinematic Hotel view
export default function CinematicHotel() {
  return (
    <div className="min-h-screen relative w-full flex flex-col items-center justify-center px-6">
      
      {/* Fluid Masked Droplet Image */}
      <div className="fluid-droplet mb-12 opacity-90 relative transition-transform hover:scale-[1.02] duration-700">
         <img 
           src="https://images.unsplash.com/photo-1542314831-c6a4d8128e36?q=80&w=1500&auto=format&fit=crop" 
           alt="The Dolder Grand"
         />
         {/* Internal ambient glow */}
         <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent pointer-events-none"></div>
      </div>

      {/* Typographic Cluster */}
      <div className="space-y-4 text-center z-10 w-full max-w-sm">
         <h1 className="text-4xl font-light tracking-normal">The Dolder Grand</h1>
         <div className="flex justify-center gap-6 text-[10px] text-gray-400 font-light tracking-[0.1em] uppercase">
            <span>Zurich</span>
            <span>$450/night</span>
            <span>5 Stars</span>
         </div>
      </div>

      {/* Ghost CTA */}
      <div className="mt-16">
        <button className="text-xl font-light liquid-fire tracking-widest uppercase hover:scale-105 transition-transform duration-300">
           Vote
        </button>
      </div>

    </div>
  );
}
