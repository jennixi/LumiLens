import React, { useEffect, useState } from "react";

export default function RaspberryPiUi() {
  // Loading animation state
  const loaderFrames = [
    "/images/loading1.png",
    "/images/loading2.png",
    "/images/loading3.png",
    "/images/loading4.png",
  ];
  const [isLoaded, setIsLoaded] = useState(false);
  const [loaderIndex, setLoaderIndex] = useState(0);

  // Main UI state
  const [showChoice, setShowChoice] = useState(false); // Set to true to test choice button
  const [friendship, setFriendship] = useState(0.5); // 0..1

  // Animate loading frames
  useEffect(() => {
    if (isLoaded) return;
    if (loaderIndex < loaderFrames.length - 1) {
      const t = setTimeout(() => setLoaderIndex(loaderIndex + 1), 1000);
      return () => clearTimeout(t);
    } else {
      // After last frame, wait 1s then show main UI
      const t = setTimeout(() => setIsLoaded(true), 1000);
      return () => clearTimeout(t);
    }
  }, [loaderIndex, isLoaded]);

  // Friendship bar image logic
  function friendshipBarImageForValue(v) {
    if (v <= 0) return "/images/friendshipbar_empty.png";
    if (v <= 0.25) return "/images/friendshipbar_quarterfull.png";
    if (v <= 0.5) return "/images/friendshipbar_halffull.png";
    if (v <= 0.75) return "/images/friendshipbar_75full.png";
    return "/images/friendshipbar_full.png";
  }

  if (!isLoaded) {
    // Loading animation, full screen
    return (
      <div className="w-screen h-screen bg-black flex items-center justify-center overflow-hidden">
        <img
          src={loaderFrames[loaderIndex]}
          alt="loading"
          className="w-full h-full object-cover"
        />
      </div>
    );
  }

  // Main UI layout
  return (
    <div className="w-screen h-screen bg-black overflow-hidden relative">
      {/* Cat sprite in bottom left, closer to edge */}
      <img
        src="/images/catneutral.png"
        alt="cat"
        className="fixed left-2 bottom-2 w-32 h-32 object-contain z-10"
        style={{ pointerEvents: "none", margin: 0 }}
      />
      {/* Heart stacked directly above friendship bar in top right */}
      <div className="fixed right-4 top-4 flex flex-col items-end z-20" style={{gap: 0}}>
        <img
          src="/images/heartpixel.png"
          alt="heart"
          className="w-14 h-14 object-contain"
          style={{ pointerEvents: "none", marginBottom: 0 }}
        />
        <img
          src={friendshipBarImageForValue(friendship)}
          alt="friendship-bar"
          className="w-32 h-7 object-contain"
          style={{ pointerEvents: "none", marginTop: 0 }}
        />
      </div>
      {/* Choice button (only if showChoice) */}
      {showChoice && (
        <button
          className="absolute bottom-8 left-1/2 transform -translate-x-1/2 z-20"
          style={{ background: "none", border: "none", padding: 0 }}
          onClick={() => setShowChoice(false)}
        >
          <img src="/images/choice1.png" alt="choice" className="w-32 h-32 object-contain" />
        </button>
      )}
    </div>
  );
}

