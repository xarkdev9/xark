"use client";

// Simple constellation spatial layout
export default function Constellation() {
  return (
    <div className="min-h-screen relative w-full overflow-hidden flex items-center justify-center">
      {/* Central focal node */}
      <div className="absolute z-10 scale-110 flex flex-col items-center justify-center">
         <h2 className="text-5xl font-light liquid-fire tracking-tight">Flights to Swiss</h2>
         <p className="text-center mt-4 text-[10px] font-light text-gray-400 uppercase tracking-[0.2em]">4 Travelers • $1,200 avg</p>
      </div>

      {/* Orbiting nodes (simulating manual spatial layout via absolute positioning) */}
      <div className="absolute top-24 left-12 opacity-30 blur-sm scale-75 cursor-pointer hover:blur-none hover:opacity-100 transition-all duration-700">
         <h2 className="text-3xl font-light tracking-wide">The Dolder Grand</h2>
      </div>

      <div className="absolute bottom-32 right-16 opacity-40 blur-[2px] scale-90 cursor-pointer hover:blur-none hover:opacity-100 transition-all duration-700">
         <h2 className="text-3xl font-light tracking-wide">Itinerary</h2>
      </div>

      <div className="absolute top-48 right-24 opacity-20 blur-md scale-50 cursor-pointer hover:blur-none hover:opacity-100 transition-all duration-700">
         <h2 className="text-3xl font-light tracking-wide">Splitwise</h2>
      </div>

      {/* Ghost UI hint */}
      <div className="absolute bottom-12 text-center w-full">
         <p className="text-[10px] font-light text-gray-600 uppercase tracking-widest">Pan to explore</p>
      </div>
    </div>
  );
}
