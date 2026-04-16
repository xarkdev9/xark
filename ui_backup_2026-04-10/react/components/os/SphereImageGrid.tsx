import React, { useState, useEffect, useRef, useCallback } from 'react';

export interface Position3D {
  x: number;
  y: number;
  z: number;
}

export interface SphericalPosition {
  theta: number;
  phi: number;
  radius: number;
}

export interface WorldPosition extends Position3D {
  scale: number;
  zIndex: number;
  isVisible: boolean;
  fadeOpacity: number;
  originalIndex: number;
}

export type NodeType = 'category' | 'action' | 'item';

export interface SphereNode {
  id: string;
  type: NodeType;
  label: string;
  imageUrl?: string;
  actionText?: string;
  score?: number;
}

export interface SphereImageGridProps {
  items?: SphereNode[];
  containerSize?: number;
  sphereRadius?: number;
  dragSensitivity?: number;
  momentumDecay?: number;
  maxRotationSpeed?: number;
  baseItemScale?: number;
  hoverScale?: number;
  perspective?: number;
  autoRotate?: boolean;
  autoRotateSpeed?: number;
  className?: string;
  onNodeClick?: (node: SphereNode) => void;
}

interface RotationState {
  x: number;
  y: number;
  z: number;
}

interface VelocityState {
  x: number;
  y: number;
}

interface MousePosition {
  x: number;
  y: number;
}

const SPHERE_MATH = {
  degreesToRadians: (degrees: number): number => degrees * (Math.PI / 180),
  radiansToDegrees: (radians: number): number => radians * (180 / Math.PI),

  sphericalToCartesian: (radius: number, theta: number, phi: number): Position3D => ({
    x: radius * Math.sin(phi) * Math.cos(theta),
    y: radius * Math.cos(phi),
    z: radius * Math.sin(phi) * Math.sin(theta)
  }),

  calculateDistance: (pos: Position3D, center: Position3D = { x: 0, y: 0, z: 0 }): number => {
    const dx = pos.x - center.x;
    const dy = pos.y - center.y;
    const dz = pos.z - center.z;
    return Math.sqrt(dx * dx + dy * dy + dz * dz);
  },

  normalizeAngle: (angle: number): number => {
    while (angle > 180) angle -= 360;
    while (angle < -180) angle += 360;
    return angle;
  }
};

const SphereImageGrid: React.FC<SphereImageGridProps> = ({
  items = [],
  containerSize = 400,
  sphereRadius = 200,
  dragSensitivity = 0.5,
  momentumDecay = 0.95,
  maxRotationSpeed = 5,
  baseItemScale = 0.22,
  hoverScale = 1.2,
  perspective = 1000,
  autoRotate = false,
  autoRotateSpeed = 0.3,
  className = '',
  onNodeClick
}) => {

  const [isMounted, setIsMounted] = useState<boolean>(false);
  const [rotation, setRotation] = useState<RotationState>({ x: 15, y: 15, z: 0 });
  const [velocity, setVelocity] = useState<VelocityState>({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState<boolean>(false);
  const [selectedNode, setSelectedNode] = useState<SphereNode | null>(null);
  const [imagePositions, setImagePositions] = useState<SphericalPosition[]>([]);
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);

  const containerRef = useRef<HTMLDivElement>(null);
  const lastMousePos = useRef<MousePosition>({ x: 0, y: 0 });
  const animationFrame = useRef<number | null>(null);

  const actualSphereRadius = sphereRadius || containerSize * 0.5;
  const baseImageSize = containerSize * baseItemScale;

  const generateSpherePositions = useCallback((): SphericalPosition[] => {
    const positions: SphericalPosition[] = [];
    const imageCount = items.length;
    const goldenRatio = (1 + Math.sqrt(5)) / 2;
    const angleIncrement = 2 * Math.PI / goldenRatio;

    for (let i = 0; i < imageCount; i++) {
      const t = i / imageCount;
      const inclination = Math.acos(1 - 2 * t);
      const azimuth = angleIncrement * i;
      let phi = inclination * (180 / Math.PI);
      let theta = (azimuth * (180 / Math.PI)) % 360;

      const poleBonus = Math.pow(Math.abs(phi - 90) / 90, 0.6) * 35;
      if (phi < 90) {
        phi = Math.max(5, phi - poleBonus);
      } else {
        phi = Math.min(175, phi + poleBonus);
      }

      phi = 15 + (phi / 180) * 150;
      const randomOffset = (Math.random() - 0.5) * 20;
      theta = (theta + randomOffset) % 360;
      phi = Math.max(0, Math.min(180, phi + (Math.random() - 0.5) * 10));

      positions.push({ theta, phi, radius: actualSphereRadius });
    }
    return positions;
  }, [items.length, actualSphereRadius]);

  const calculateWorldPositions = useCallback((): WorldPosition[] => {
    const positions = imagePositions.map((pos, index) => {
      const thetaRad = SPHERE_MATH.degreesToRadians(pos.theta);
      const phiRad = SPHERE_MATH.degreesToRadians(pos.phi);
      const rotXRad = SPHERE_MATH.degreesToRadians(rotation.x);
      const rotYRad = SPHERE_MATH.degreesToRadians(rotation.y);

      let x = pos.radius * Math.sin(phiRad) * Math.cos(thetaRad);
      let y = pos.radius * Math.cos(phiRad);
      let z = pos.radius * Math.sin(phiRad) * Math.sin(thetaRad);

      const x1 = x * Math.cos(rotYRad) + z * Math.sin(rotYRad);
      const z1 = -x * Math.sin(rotYRad) + z * Math.cos(rotYRad);
      x = x1;
      z = z1;

      const y2 = y * Math.cos(rotXRad) - z * Math.sin(rotXRad);
      const z2 = y * Math.sin(rotXRad) + z * Math.cos(rotXRad);
      y = y2;
      z = z2;

      const worldPos: Position3D = { x, y, z };
      const fadeZoneStart = -10;
      const fadeZoneEnd = -50;
      const isVisible = worldPos.z > fadeZoneEnd;

      let fadeOpacity = 1;
      if (worldPos.z <= fadeZoneStart) {
        fadeOpacity = Math.max(0, (worldPos.z - fadeZoneEnd) / (fadeZoneStart - fadeZoneEnd));
      }

      const isPoleImage = pos.phi < 30 || pos.phi > 150;
      const distanceFromCenter = Math.sqrt(worldPos.x * worldPos.x + worldPos.y * worldPos.y);
      const maxDistance = actualSphereRadius;
      const distanceRatio = Math.min(distanceFromCenter / maxDistance, 1);
      const distancePenalty = isPoleImage ? 0.4 : 0.7;
      const centerScale = Math.max(0.3, 1 - distanceRatio * distancePenalty);
      const depthScale = (worldPos.z + actualSphereRadius) / (2 * actualSphereRadius);
      const scale = centerScale * Math.max(0.4, 0.7 + depthScale * 0.4);

      return {
        ...worldPos, scale, zIndex: Math.round(1000 + worldPos.z),
        isVisible, fadeOpacity, originalIndex: index
      };
    });

    const adjustedPositions = [...positions];
    for (let i = 0; i < adjustedPositions.length; i++) {
      const pos = adjustedPositions[i];
      if (!pos.isVisible) continue;
      let adjustedScale = pos.scale;
      const imageSize = baseImageSize * adjustedScale;

      for (let j = 0; j < adjustedPositions.length; j++) {
        if (i === j) continue;
        const other = adjustedPositions[j];
        if (!other.isVisible) continue;
        const otherSize = baseImageSize * other.scale;
        const dx = pos.x - other.x;
        const dy = pos.y - other.y;
        const distance = Math.sqrt(dx * dx + dy * dy);
        const minDistance = (imageSize + otherSize) / 2 + 10;

        if (distance < minDistance && distance > 0) {
          const overlap = minDistance - distance;
          const reductionFactor = Math.max(0.5, 1 - (overlap / minDistance) * 0.4);
          adjustedScale = Math.min(adjustedScale, adjustedScale * reductionFactor);
        }
      }
      adjustedPositions[i] = { ...pos, scale: Math.max(0.3, adjustedScale) };
    }
    return adjustedPositions;
  }, [imagePositions, rotation, actualSphereRadius, baseImageSize]);

  const clampRotationSpeed = useCallback((speed: number): number => {
    return Math.max(-maxRotationSpeed, Math.min(maxRotationSpeed, speed));
  }, [maxRotationSpeed]);

  const updateMomentum = useCallback(() => {
    if (isDragging) return;
    setVelocity(prev => {
      const newVelocity = { x: prev.x * momentumDecay, y: prev.y * momentumDecay };
      if (!autoRotate && Math.abs(newVelocity.x) < 0.01 && Math.abs(newVelocity.y) < 0.01) return { x: 0, y: 0 };
      return newVelocity;
    });
    setRotation(prev => {
      let newY = prev.y + (autoRotate ? autoRotateSpeed : 0) + clampRotationSpeed(velocity.y);
      return {
        x: SPHERE_MATH.normalizeAngle(prev.x + clampRotationSpeed(velocity.x)),
        y: SPHERE_MATH.normalizeAngle(newY),
        z: prev.z
      };
    });
  }, [isDragging, momentumDecay, velocity, clampRotationSpeed, autoRotate, autoRotateSpeed]);

  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    setIsDragging(true); setVelocity({ x: 0, y: 0 });
    lastMousePos.current = { x: e.clientX, y: e.clientY };
  }, []);

  const handleMouseMove = useCallback((e: MouseEvent) => {
    if (!isDragging) return;
    const deltaX = e.clientX - lastMousePos.current.x;
    const deltaY = e.clientY - lastMousePos.current.y;
    const rotationDelta = { x: -deltaY * dragSensitivity, y: deltaX * dragSensitivity };

    setRotation(prev => ({
      x: SPHERE_MATH.normalizeAngle(prev.x + clampRotationSpeed(rotationDelta.x)),
      y: SPHERE_MATH.normalizeAngle(prev.y + clampRotationSpeed(rotationDelta.y)),
      z: prev.z
    }));
    setVelocity({ x: clampRotationSpeed(rotationDelta.x), y: clampRotationSpeed(rotationDelta.y) });
    lastMousePos.current = { x: e.clientX, y: e.clientY };
  }, [isDragging, dragSensitivity, clampRotationSpeed]);

  const handleMouseUp = useCallback(() => { setIsDragging(false); }, []);

  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    e.preventDefault(); const touch = e.touches[0];
    setIsDragging(true); setVelocity({ x: 0, y: 0 });
    lastMousePos.current = { x: touch.clientX, y: touch.clientY };
  }, []);

  const handleTouchMove = useCallback((e: TouchEvent) => {
    if (!isDragging) return; e.preventDefault();
    const touch = e.touches[0];
    const deltaX = touch.clientX - lastMousePos.current.x;
    const deltaY = touch.clientY - lastMousePos.current.y;
    const rotationDelta = { x: -deltaY * dragSensitivity, y: deltaX * dragSensitivity };

    setRotation(prev => ({
      x: SPHERE_MATH.normalizeAngle(prev.x + clampRotationSpeed(rotationDelta.x)),
      y: SPHERE_MATH.normalizeAngle(prev.y + clampRotationSpeed(rotationDelta.y)),
      z: prev.z
    }));
    setVelocity({ x: clampRotationSpeed(rotationDelta.x), y: clampRotationSpeed(rotationDelta.y) });
    lastMousePos.current = { x: touch.clientX, y: touch.clientY };
  }, [isDragging, dragSensitivity, clampRotationSpeed]);

  const handleTouchEnd = useCallback(() => { setIsDragging(false); }, []);

  useEffect(() => { setIsMounted(true); }, []);
  useEffect(() => { setImagePositions(generateSpherePositions()); }, [generateSpherePositions]);

  useEffect(() => {
    const animate = () => { updateMomentum(); animationFrame.current = requestAnimationFrame(animate); };
    if (isMounted) animationFrame.current = requestAnimationFrame(animate);
    return () => { if (animationFrame.current) cancelAnimationFrame(animationFrame.current); };
  }, [isMounted, updateMomentum]);

  useEffect(() => {
    if (!isMounted || !containerRef.current) return;
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
    document.addEventListener('touchmove', handleTouchMove, { passive: false });
    document.addEventListener('touchend', handleTouchEnd);
    return () => {
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
      document.removeEventListener('touchmove', handleTouchMove);
      document.removeEventListener('touchend', handleTouchEnd);
    };
  }, [isMounted, handleMouseMove, handleMouseUp, handleTouchMove, handleTouchEnd]);

  const worldPositions = calculateWorldPositions();

  const renderSphereNode = useCallback((node: SphereNode, index: number) => {
    const position = worldPositions[index];
    if (!position || !position.isVisible) return null;

    const baseSize = baseImageSize * position.scale;
    const isHovered = hoveredIndex === index;
    const finalScale = isHovered ? Math.min(1.2, 1.2 / position.scale) : 1;

    let content;

    if (node.type === 'category') {
      content = (
        <div className="flex flex-col items-center justify-center w-full h-full rounded-full" style={{ background: 'rgba(255,255,255,0.05)', backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)', border: '1px solid rgba(255,255,255,0.15)', boxShadow: '0 8px 32px rgba(0,0,0,0.3)' }}>
           <span style={{ fontSize: Math.max(12, baseSize * 0.16), color: '#F8F7F4', fontWeight: 300, letterSpacing: '0.05em', textAlign: 'center' }}>
             {node.label}
           </span>
        </div>
      );
    } else if (node.type === 'action') {
      content = (
        <div className="flex flex-col items-center justify-center w-full h-full rounded-full relative overflow-hidden" style={{ background: 'linear-gradient(135deg, #FF6B35 0%, #8B2500 100%)', boxShadow: '0 0 20px rgba(255,107,53,0.4)', border: '1px solid rgba(255,255,255,0.2)' }}>
           <div className="absolute inset-0" style={{ background: 'radial-gradient(circle at 50% 0%, rgba(255,255,255,0.3) 0%, transparent 60%)' }} />
           <span style={{ fontSize: Math.max(10, baseSize * 0.13), color: '#FFF', fontWeight: 500, textAlign: 'center', padding: '0 10%', zIndex: 2, lineHeight: 1.2 }}>
             {node.label}
           </span>
           {node.actionText && (
             <div style={{ marginTop: baseSize * 0.08, background: 'rgba(0,0,0,0.3)', padding: '4px 10px', borderRadius: 12, fontSize: Math.max(8, baseSize * 0.1), color: 'rgba(255,255,255,0.9)', zIndex: 2 }}>
               {node.actionText}
             </div>
           )}
        </div>
      );
    } else {
      content = (
        <div className="relative w-full h-full rounded-full overflow-hidden shadow-xl border border-white/10" style={{ background: '#111' }}>
          {node.imageUrl ? (
            <img src={node.imageUrl} alt={node.label} className="w-full h-full object-cover" draggable={false} />
          ) : (
            <div className="w-full h-full bg-gray-800" />
          )}
          <div className="absolute inset-0" style={{ background: 'linear-gradient(to top, rgba(0,0,0,0.85) 0%, transparent 50%)' }} />
          <div className="absolute bottom-0 left-0 right-0 flex justify-center pb-4 px-2">
             <span style={{ fontSize: Math.max(11, baseSize * 0.14), color: '#FFF', fontWeight: 300, textShadow: '0 2px 10px rgba(0,0,0,0.8)', textAlign: 'center', lineHeight: 1.2 }}>
               {node.label}
             </span>
          </div>
          {node.score && (
            <div className="absolute top-2 right-2 flex items-center justify-center rounded-full bg-black/50 backdrop-blur" style={{ width: baseSize*0.25, height: baseSize*0.25, minWidth: 24, minHeight: 24, border: '1px solid rgba(255,255,255,0.1)' }}>
               <span style={{ color: '#F5A623', fontSize: Math.max(9, baseSize*0.1), fontWeight: 600 }}>{node.score}</span>
            </div>
          )}
        </div>
      );
    }

    return (
      <div
        key={node.id}
        className="absolute cursor-pointer select-none transition-transform duration-200 ease-out"
        style={{
          width: `${baseSize}px`, height: `${baseSize}px`,
          left: `${containerSize/2 + position.x}px`,
          top: `${containerSize/2 + position.y}px`,
          opacity: position.fadeOpacity,
          transform: `translate(-50%, -50%) scale(${finalScale})`,
          zIndex: position.zIndex
        }}
        onMouseEnter={() => setHoveredIndex(index)}
        onMouseLeave={() => setHoveredIndex(null)}
        onClick={() => {
          if (onNodeClick) {
            onNodeClick(node);
          } else {
            setSelectedNode(node);
          }
        }}
      >
        {content}
      </div>
    );
  }, [worldPositions, baseImageSize, containerSize, hoveredIndex]);

  const renderSpotlightModal = () => {
    if (!selectedNode) return null;
    return (
      <div
        className="fixed inset-0 z-[9999] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
        onClick={() => setSelectedNode(null)}
        style={{ animation: 'fadeIn 0.3s ease-out' }}
      >
        <div className="bg-[#111] border border-white/10 rounded-2xl max-w-sm w-full overflow-hidden shadow-2xl" onClick={(e) => e.stopPropagation()} style={{ animation: 'scaleIn 0.3s ease-out' }}>
          {selectedNode.type === 'item' && selectedNode.imageUrl ? (
            <div className="relative aspect-video">
              <img src={selectedNode.imageUrl} alt={selectedNode.label} className="w-full h-full object-cover" />
              {selectedNode.score && (
                <div className="absolute top-4 left-4 flex items-center justify-center rounded-full bg-black/70 backdrop-blur text-[#F5A623] font-semibold px-3 py-1 text-sm border border-white/10">
                  ★ {selectedNode.score} Score
                </div>
              )}
            </div>
          ) : (
             <div className="w-full h-24 bg-gradient-to-br from-[#1C1C1E] to-black" />
          )}

          <div className="p-6 relative">
             <div className="mb-2 uppercase tracking-widest text-[10px] text-[#A1A1A6] font-light">
               {selectedNode.type} Node
             </div>
             <h3 className="text-2xl font-light text-[#F8F7F4] mb-2">{selectedNode.label}</h3>
             
             {selectedNode.actionText && (
               <button className="w-full mt-4 py-3 rounded-xl bg-[#FF6B35] text-white font-medium hover:bg-[#cc5522] transition-colors relative z-10">
                 {selectedNode.actionText}
               </button>
             )}
          </div>
          <button onClick={() => setSelectedNode(null)} className="absolute top-4 right-4 w-8 h-8 rounded-full text-white flex items-center justify-center cursor-pointer hover:bg-white/10 transition-colors z-[10000]" style={{ background: 'rgba(0,0,0,0.5)', border: '1px solid rgba(255,255,255,0.1)' }}>
            ✕
          </button>
        </div>
      </div>
    );
  };

  if (!isMounted) return <div style={{ width: containerSize, height: containerSize }} />;
  if (!items.length) return <div style={{ width: containerSize, height: containerSize }} />;

  return (
    <>
      <style>{`
        @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
        @keyframes scaleIn { from { transform: scale(0.9); opacity: 0; } to { transform: scale(1); opacity: 1; } }
      `}</style>
      <div
        ref={containerRef}
        className={`relative select-none cursor-grab active:cursor-grabbing ${className}`}
        style={{ width: containerSize, height: containerSize, perspective: `${perspective}px` }}
        onMouseDown={handleMouseDown}
        onTouchStart={handleTouchStart}
      >
        <div className="relative w-full h-full" style={{ zIndex: 10 }}>
          {items.map((node, index) => renderSphereNode(node, index))}
        </div>
      </div>
      {renderSpotlightModal()}
    </>
  );
};

export default React.memo(SphereImageGrid);
