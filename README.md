# PDF Canvas (freeform builder)

[![Build & Deploy](https://github.com/AllinGaming/flutter_to_pdf/actions/workflows/gh-pages.yml/badge.svg)](https://github.com/AllinGaming/flutter_to_pdf/actions/workflows/gh-pages.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-teal)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Web-blue)]()
[![Coverage](https://allingaming.github.io/flutter_to_pdf/coverage_badge.svg)](https://allingaming.github.io/flutter_to_pdf/coverage_badge.svg)
[![Static Analysis](https://img.shields.io/badge/Analyzer-clean-success)]()
[![GH Pages](https://img.shields.io/badge/GitHub%20Pages-live-success)](https://allingaming.github.io/flutter_to_pdf/)
[![License](https://img.shields.io/badge/License-MIT-black)](LICENSE)

Drag-and-drop PDF builder on an A4 canvas. Add text, rectangles, and images; position and resize them freely; then preview/print/download a PDF.

This is not the flutter_to_pdf pub package, this is an independent project.

## Features
- Refreshed UI: gradient chrome, status chips, sticky toolbar for zoom/snap/share.
- Templates to seed layouts (hero cover, two-column brief, header + body, callout block) plus grid/margin guides.
- Palette to add text, rectangles, and images; inspector for text styling (size/color/bold) and color swatches.
- Layout controls: manual W/H/X/Y, duplicate, bring forward/back, center alignment, opacity & corner radius controls for boxes/images, quick delete.
- Live PDF preview using `printing` + `pdf`; one-click share/download and accurate color/text weight mapping.
- GitHub Actions workflow builds/tests (with coverage) and deploys the web build to `gh-pages`.
- Configurable guides and snapping (adjust grid spacing, margins, and snap step).