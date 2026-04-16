"use client";
import { useState } from "react";

export default function ChatBridge() {
  const [isDilated, setIsDilated] = useState(false);

  return (
    <div className="flex flex-col items-center justify-center min-h-screen relative px-6">
      {/* Background Chat that refracts */}
      <div 
        className={`refract-void w-full max-w-md space-y-12 flex flex-col pt-24 ${isDilated ? 'refract-active' : ''}`}
        onClick={() => setIsDilated(!isDilated)}
      >
        <p className="text-xl font-light text-center opacity-70">who is booking the flights?</p>
        <div className="flex flex-col items-center cursor-pointer hover:scale-105 transition-transform">
          <p className="text-xl font-light text-center liquid-fire tracking-wide">
            @xark Swiss in June
          </p>
          <span className="text-[10px] uppercase tracking-widest text-gray-500 mt-2">Tap to expand</span>
        </div>
        <p className="text-xl font-light text-center opacity-70">I found a nice hotel in Zurich.</p>
      </div>

      {/* The Plan World that materializes */}
      {isDilated && (
        <div className="absolute inset-0 flex flex-col items-center justify-center animate-in fade-in zoom-in duration-700">
           <h1 className="text-4xl font-light mb-16 tracking-widest uppercase opacity-80">Swiss in June</h1>
           <div className="grid grid-cols-2 gap-12 text-center">
              <div className="space-y-2 cursor-pointer hover:scale-110 transition-transform">
                <p className="text-2xl font-light liquid-fire relative">Flights</p>
                <p className="text-[10px] font-light text-gray-500 uppercase tracking-widest">3 Options</p>
              </div>
              <div className="space-y-2 opacity-50 cursor-pointer hover:opacity-100 transition-opacity">
                <p className="text-2xl font-light">Hotels</p>
                <p className="text-[10px] font-light text-gray-500 uppercase tracking-widest">Voting</p>
              </div>
              <div className="col-span-2 space-y-2 opacity-50 pt-8 cursor-pointer hover:opacity-100 transition-opacity">
                <p className="text-2xl font-light">Itinerary</p>
                <p className="text-[10px] font-light text-gray-500 uppercase tracking-widest">Unpacked</p>
              </div>
           </div>
           <button 
             className="absolute bottom-12 text-xs font-light text-gray-400 uppercase tracking-widest hover:text-white"
             onClick={() => setIsDilated(false)}
           >
             Close Void
           </button>
        </div>
      )}
    </div>
  );
}
