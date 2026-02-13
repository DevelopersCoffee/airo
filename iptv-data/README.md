# IPTV Sanity Agent

A production-grade offline preprocessing pipeline for IPTV channel data. This system fetches, validates, deduplicates, and enriches IPTV channel data from multiple sources, producing clean JSON artifacts for client consumption.

> **Note:** This is part of the `airo` monorepo. The pipeline runs via GitHub Actions and outputs are committed to `iptv-data/output/current/`.

## 🎯 Purpose

The app becomes a **pure consumer of trusted data**, not a cleanup engine. All sanitation, validation, deduplication, and enrichment happens **offline** in this pipeline.

## 🏗️ Architecture

```
IPTV Sources (Raw)
 ├─ Default M3U Playlist
 ├─ IPTV-org API
 └─ Custom Sources
        ↓
GitHub Processing Pipeline (IPTV Sanity Agent)
        ↓
Sanitized & Consolidated Output (Versioned JSON)
        ↓
Client Apps (Mobile / Web)
```

## 📁 Project Structure

```
iptv-data/
├── config/                    # Configuration files
│   ├── default.yaml          # Production config
│   └── development.yaml      # Dev/testing config
├── rules/                     # Enrichment rules
│   ├── flavor_rules.json     # Flavor tagging
│   ├── category_rules.json   # Category mapping
│   └── language_rules.json   # Language detection
├── src/                       # Source code
│   ├── loaders/              # Source loaders
│   ├── processors/           # Processing pipeline
│   ├── exporters/            # Output exporters
│   └── utils/                # Utilities
├── tests/                     # Test suite
├── output/                    # Generated artifacts
│   ├── current/              # Latest version
│   ├── previous/             # Rollback target
│   └── archive/              # Historical versions
└── .github/workflows/         # CI/CD
```

## 🚀 Quick Start

### Prerequisites

- Python 3.11+
- pip or poetry

### Installation

```bash
cd iptv-data
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Run Pipeline

```bash
# Full pipeline
python -m src.main --config config/default.yaml

# Skip stream validation (faster, for testing)
python -m src.main --config config/default.yaml --skip-validation

# Development mode
python -m src.main --config config/development.yaml
```

### Run Tests

```bash
pytest tests/ -v
```

## ⚙️ Configuration

See `config/default.yaml` for all configuration options. Key settings:

- **sources**: Configure M3U URLs, IPTV-org API, custom sources
- **processing**: Validation, deduplication, normalization rules
- **output**: Format, versioning, thresholds

## 📤 Output

The pipeline produces:

- `output/current/iptv_channels.json` - Main channel data
- `output/current/manifest.json` - Version metadata
- `output/reports/pipeline_report.json` - Run statistics

## 🔄 GitHub Actions

The pipeline runs automatically via `.github/workflows/iptv_sanity.yml`:
- **Daily at 00:00 UTC** (scheduled)
- **On push to main** (when `iptv-data/` files change)
- **Manual trigger** (workflow_dispatch)

The workflow:
1. Runs linting and tests
2. Executes the pipeline
3. **Publishes output to GitHub Gist** (publicly accessible)
4. Uploads artifacts for 30-day retention

## 🔧 Gist Setup (Required)

To enable automatic publishing, you need to create a GitHub Gist and configure secrets:

### Step 1: Create a Public Gist

1. Go to [gist.github.com](https://gist.github.com)
2. Create a new **public** gist with these placeholder files:
   - `iptv_channels.json` (content: `{}`)
   - `manifest.json` (content: `{}`)
   - `iptv_channels.m3u` (content: `#EXTM3U`)
3. Copy the Gist ID from the URL (e.g., `https://gist.github.com/username/abc123def456` → ID is `abc123def456`)

### Step 2: Create a Personal Access Token

1. Go to [GitHub Settings > Developer settings > Personal access tokens > Tokens (classic)](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Give it a name like "IPTV Gist Publisher"
4. Select scope: **`gist`** (Create gists)
5. Generate and copy the token

### Step 3: Add Repository Secrets

In your repository settings, add these secrets:

| Secret Name | Value |
|-------------|-------|
| `IPTV_GIST_ID` | The Gist ID from Step 1 |
| `GIST_TOKEN` | The Personal Access Token from Step 2 |

### Step 4: Update Flutter App

In `app/lib/features/iptv/domain/services/channel_data_service.dart`, update the Gist ID:

```dart
static const String _gistId = 'YOUR_GIST_ID_HERE';  // Replace with actual Gist ID
```

### Gist URLs

Once configured, the data will be available at:
- **JSON**: `https://gist.githubusercontent.com/raw/{GIST_ID}/iptv_channels.json`
- **M3U**: `https://gist.githubusercontent.com/raw/{GIST_ID}/iptv_channels.m3u`
- **Manifest**: `https://gist.githubusercontent.com/raw/{GIST_ID}/manifest.json`

## 📋 Implementation Status

All components implemented and tested:

- [x] Repository setup and scaffolding
- [x] Configuration schema and YAML loader
- [x] M3U loader implementation
- [x] IPTV-org API loader
- [x] Channel normalizer
- [x] Stream validator
- [x] Deduplicator
- [x] Flavor/category enricher
- [x] JSON/M3U exporters
- [x] GitHub Actions workflow
- [x] Flutter app integration

## 📊 Test Coverage

- **44 unit tests** covering all core components
- **53% code coverage** (loaders, processors, models)
- **32 Flutter tests** for IPTV feature integration

## 📄 License

MIT License - See LICENSE file for details.

