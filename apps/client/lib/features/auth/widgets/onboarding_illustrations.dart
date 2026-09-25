// Illustrations de l'onboarding (portage des SVG inline du prototype
// web, figés dans leur état final d'animation). Identité tirée du
// logo : cercle ouvert, route sinueuse, pin GPS, ondes, bus stylisé.

const String _grid = '''
  <line x1="40" y1="30" x2="40" y2="210" stroke="#ffffff" stroke-width="0.5" opacity="0.06"/>
  <line x1="80" y1="30" x2="80" y2="210" stroke="#ffffff" stroke-width="0.5" opacity="0.06"/>
  <line x1="120" y1="30" x2="120" y2="210" stroke="#ffffff" stroke-width="0.5" opacity="0.06"/>
  <line x1="160" y1="30" x2="160" y2="210" stroke="#ffffff" stroke-width="0.5" opacity="0.06"/>
  <line x1="200" y1="30" x2="200" y2="210" stroke="#ffffff" stroke-width="0.5" opacity="0.06"/>
  <line x1="240" y1="30" x2="240" y2="210" stroke="#ffffff" stroke-width="0.5" opacity="0.06"/>
  <line x1="20" y1="50" x2="260" y2="50" stroke="#ffffff" stroke-width="0.5" opacity="0.06"/>
  <line x1="20" y1="90" x2="260" y2="90" stroke="#ffffff" stroke-width="0.5" opacity="0.06"/>
  <line x1="20" y1="130" x2="260" y2="130" stroke="#ffffff" stroke-width="0.5" opacity="0.06"/>
  <line x1="20" y1="170" x2="260" y2="170" stroke="#ffffff" stroke-width="0.5" opacity="0.06"/>
''';

const String voyagerIllustrationSvg =
    '''
<svg width="280" height="220" viewBox="0 0 280 220" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="vyroad" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#1b2a47"/>
      <stop offset="100%" stop-color="#0a2540"/>
    </linearGradient>
    <linearGradient id="vybus" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#f8f9fa"/>
      <stop offset="100%" stop-color="#e0e4ec"/>
    </linearGradient>
  </defs>
  <path d="M 140 20 A 90 90 0 0 1 200 50" stroke="#ff6600" stroke-width="6" stroke-linecap="round" fill="none" opacity="0.3"/>
  <path d="M 80 180 A 90 90 0 0 0 200 180" stroke="#ffffff" stroke-width="6" stroke-linecap="round" fill="none" opacity="0.3"/>
  $_grid
  <path d="M 30 190 Q 80 190, 80 150 T 140 110 Q 180 110, 180 80 T 250 50" stroke="url(#vyroad)" stroke-width="22" stroke-linecap="round" fill="none"/>
  <path d="M 30 190 Q 80 190, 80 150 T 140 110 Q 180 110, 180 80 T 250 50" stroke="#ffffff" stroke-width="1.5" stroke-dasharray="6 8" stroke-linecap="round" fill="none" opacity="0.6"/>
  <path d="M 30 178 C 30 172, 36 168, 42 168 C 48 168, 54 172, 54 178 C 54 186, 42 198, 42 198 C 42 198, 30 186, 30 178 Z" fill="#ff6600"/>
  <circle cx="42" cy="176" r="4" fill="#ffffff"/>
  <circle cx="250" cy="50" r="9" fill="#ff6600" opacity="0.3"/>
  <circle cx="250" cy="50" r="6" fill="#ff6600"/>
  <circle cx="250" cy="50" r="2.5" fill="#ffffff"/>
  <path d="M 245 42 a8 8 0 0 1 10 0" stroke="#ff6600" stroke-width="2" stroke-linecap="round" fill="none" opacity="0.8"/>
  <path d="M 242 38 a14 14 0 0 1 16 0" stroke="#ff6600" stroke-width="1.5" stroke-linecap="round" fill="none" opacity="0.5"/>
  <g transform="translate(95, 82) rotate(-15)">
    <rect x="0" y="0" width="50" height="22" rx="4" fill="url(#vybus)"/>
    <rect x="0" y="14" width="50" height="4" fill="#ff7a00" rx="2"/>
    <rect x="4" y="4" width="14" height="7" rx="1" fill="#0d1b2a"/>
    <rect x="20" y="4" width="12" height="7" rx="1" fill="#0d1b2a"/>
    <rect x="34" y="4" width="12" height="7" rx="1" fill="#0d1b2a"/>
    <circle cx="12" cy="22" r="3" fill="#0a2540"/>
    <circle cx="38" cy="22" r="3" fill="#0a2540"/>
    <circle cx="48" cy="10" r="1.5" fill="#ffeb99"/>
  </g>
</svg>
''';

const String colisIllustrationSvg =
    '''
<svg width="280" height="220" viewBox="0 0 280 220" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="cobox" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#ff8c2e"/>
      <stop offset="100%" stop-color="#ff6600"/>
    </linearGradient>
  </defs>
  <path d="M 140 20 A 90 90 0 0 1 200 50" stroke="#ffffff" stroke-width="6" stroke-linecap="round" fill="none" opacity="0.3"/>
  <path d="M 80 180 A 90 90 0 0 0 200 180" stroke="#ff6600" stroke-width="6" stroke-linecap="round" fill="none" opacity="0.3"/>
  $_grid
  <path d="M 40 180 Q 80 180, 100 140 Q 120 100, 160 90 Q 200 80, 240 40" stroke="#ffffff" stroke-width="2" stroke-dasharray="5 6" stroke-linecap="round" fill="none" opacity="0.5"/>
  <path d="M 28 168 C 28 162, 34 158, 40 158 C 46 158, 52 162, 52 168 C 52 176, 40 188, 40 188 C 40 188, 28 176, 28 168 Z" fill="#002060" stroke="#ffffff" stroke-width="1.5"/>
  <circle cx="40" cy="166" r="3.5" fill="#ffffff"/>
  <path d="M 228 28 C 228 22, 234 18, 240 18 C 246 18, 252 22, 252 28 C 252 36, 240 48, 240 48 C 240 48, 228 36, 228 28 Z" fill="#ff6600" stroke="#ffffff" stroke-width="1.5"/>
  <circle cx="240" cy="26" r="3.5" fill="#ffffff"/>
  <circle cx="140" cy="130" r="42" stroke="#ff6600" stroke-width="1.5" fill="none" opacity="0.3"/>
  <polygon points="110,108 140,95 170,108 140,121" fill="#ff8c2e"/>
  <rect x="110" y="108" width="60" height="44" rx="3" fill="url(#cobox)"/>
  <line x1="140" y1="108" x2="140" y2="152" stroke="#ffffff" stroke-width="1.5" opacity="0.5"/>
  <ellipse cx="140" cy="156" rx="32" ry="4" fill="#000000" opacity="0.15"/>
  <path d="M 105 125 a40 40 0 0 1 0 10" stroke="#ffffff" stroke-width="1.5" stroke-linecap="round" fill="none" opacity="0.3"/>
  <path d="M 175 125 a40 40 0 0 1 0 10" stroke="#ffffff" stroke-width="1.5" stroke-linecap="round" fill="none" opacity="0.3"/>
</svg>
''';

const String locationIllustrationSvg =
    '''
<svg width="280" height="220" viewBox="0 0 280 220" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="locar" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#f8f9fa"/>
      <stop offset="100%" stop-color="#d0d5dd"/>
    </linearGradient>
    <linearGradient id="lokey" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#ff8c2e"/>
      <stop offset="100%" stop-color="#ff6600"/>
    </linearGradient>
  </defs>
  <path d="M 140 25 A 95 95 0 0 1 205 60" stroke="#002060" stroke-width="7" stroke-linecap="round" fill="none" opacity="0.35"/>
  <path d="M 75 175 A 95 95 0 0 0 205 175" stroke="#ff6600" stroke-width="7" stroke-linecap="round" fill="none" opacity="0.35"/>
  $_grid
  <circle cx="140" cy="135" r="60" stroke="#ff6600" stroke-width="1" fill="none" opacity="0.15"/>
  <circle cx="140" cy="135" r="45" stroke="#ff6600" stroke-width="1" fill="none" opacity="0.25"/>
  <path d="M 105 145 L 105 130 Q 105 120, 115 118 L 130 110 Q 140 105, 150 110 L 165 118 Q 175 120, 175 130 L 175 145 Z" fill="url(#locar)"/>
  <path d="M 107 138 L 173 138 L 173 142 L 107 142 Z" fill="#ff7a00"/>
  <path d="M 120 122 L 132 114 Q 140 110, 148 114 L 160 122 L 160 128 L 120 128 Z" fill="#0d1b2a" opacity="0.85"/>
  <line x1="140" y1="114" x2="140" y2="128" stroke="#f8f9fa" stroke-width="1" opacity="0.3"/>
  <ellipse cx="170" cy="128" rx="3" ry="2" fill="#ffeb99"/>
  <circle cx="118" cy="148" r="7" fill="#0a2540"/>
  <circle cx="118" cy="148" r="3.5" fill="#1b2a47"/>
  <circle cx="162" cy="148" r="7" fill="#0a2540"/>
  <circle cx="162" cy="148" r="3.5" fill="#1b2a47"/>
  <ellipse cx="140" cy="160" rx="38" ry="4" fill="#000000" opacity="0.15"/>
  <circle cx="215" cy="65" r="9" fill="none" stroke="url(#lokey)" stroke-width="4"/>
  <rect x="220" y="63" width="22" height="4" rx="2" fill="url(#lokey)"/>
  <rect x="236" y="67" width="3" height="5" fill="url(#lokey)"/>
  <rect x="240" y="67" width="3" height="5" fill="url(#lokey)"/>
  <path d="M 80 125 a65 65 0 0 1 12 -18" stroke="#ffffff" stroke-width="1.5" stroke-linecap="round" fill="none" opacity="0.3"/>
  <path d="M 200 125 a65 65 0 0 1 -12 -18" stroke="#ffffff" stroke-width="1.5" stroke-linecap="round" fill="none" opacity="0.3"/>
</svg>
''';

/// Motif « swoosh » du logo, en fond (haut droite).
const String swooshTopSvg = '''
<svg viewBox="0 0 200 200" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M 100 20 A 80 80 0 0 1 172 72" stroke="#ff6600" stroke-width="14" stroke-linecap="round" fill="none"/>
  <path d="M 28 128 A 80 80 0 0 0 172 128" stroke="#ffffff" stroke-width="14" stroke-linecap="round" fill="none"/>
</svg>
''';

/// Motif « swoosh » du logo, en fond (bas gauche).
const String swooshBottomSvg = '''
<svg viewBox="0 0 200 200" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M 100 20 A 80 80 0 0 1 172 72" stroke="#ffffff" stroke-width="20" stroke-linecap="round" fill="none"/>
  <path d="M 28 128 A 80 80 0 0 0 172 128" stroke="#ff6600" stroke-width="20" stroke-linecap="round" fill="none"/>
</svg>
''';
