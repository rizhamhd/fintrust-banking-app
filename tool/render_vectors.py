"""Render original SVGs without changing their geometry or filter effects.

Requires librsvg's rsvg-convert. Source SVG files remain alongside the 3x PNGs.
"""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
for source in sorted((ROOT / 'assets/figma').glob('*.svg')):
    subprocess.run(['rsvg-convert', '--zoom=3', '--output', str(source.with_suffix('.png')), str(source)], check=True)
print('Original vector assets rendered at 3x with their original filters.')
