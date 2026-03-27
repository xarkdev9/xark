import { ImageResponse } from 'next/og'

export const runtime = 'edge'
export const alt = 'hello'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          background: '#111111', width: '100%', height: '100%', 
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        }}
      >
        <div style={{
            position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
            width: 600, height: 600, background: 'radial-gradient(circle, rgba(255,107,53,0.2) 0%, transparent 70%)',
        }} />
        <div style={{
          display: 'flex', color: '#FF6B35',
          fontSize: 180, fontWeight: 400, letterSpacing: '-0.05em',
        }}>
          hello
        </div>
        <div style={{ display: 'flex', color: '#A1A1AA', fontSize: 42, fontWeight: 300, marginTop: 0, letterSpacing: '0.02em' }}>
          the consensus engine.
        </div>
      </div>
    ),
    { ...size }
  )
}
