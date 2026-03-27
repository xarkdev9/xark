import { ImageResponse } from 'next/og'

export const runtime = 'edge'
export const size = { width: 180, height: 180 }
export const contentType = 'image/png'

export default function AppleIcon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%', height: '100%',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          background: 'linear-gradient(135deg, #8B2500 0%, #FF6B35 50%, #FF9F43 100%)',
          color: 'white', fontSize: 130, fontWeight: 400,
        }}
      >
        <span style={{ position: 'relative', top: '-6px' }}>h</span>
      </div>
    ),
    { ...size }
  )
}
