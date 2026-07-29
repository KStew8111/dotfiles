---
name: voxel51-data-pipeline
description: ML data pipeline reference for Voxel51/FiftyOne — dataset curation, annotation validation, split generation, and training set preparation. Use when working with computer vision datasets, Voxel51 workflows, or preparing data for model training.
---

# Voxel51 Data Pipeline

## When to Load

- Building or modifying ML data pipelines
- Working with Voxel51/FiftyOne for dataset management
- Curating training datasets for vision models
- Validating annotations and generating train/val/test splits
- Setting up automated data pipelines from raw sensor logs

## Core Principles

1. **Curation over Quantity.** Find the most informative samples, not the most samples. Focus on hard examples, edge cases, and distribution gaps.

2. **Pipeline Automation.** Any manual data movement is a bug. Automate the flow: raw sensor logs → curated datasets → training-ready manifests.

3. **Annotation Integrity.** Strict validation for labels and masks. A model trained on bad labels is worse than no model at all.

4. **Reproducibility.** Every pipeline run must be reproducible — versioned manifests, deterministic splits, documented random seeds.

## Voxel51/FiftyOne Workflow

```python
import fiftyone as fo

# Load dataset
dataset = fo.load_dataset("my_dataset")

# View and filter
view = dataset.match_tags("train")
view = view.filter_labels("detections", F("confidence") > 0.5)

# Export for training
view.export(
    export_dir="exports/train",
    dataset_type=fo.types.YOLOv5Dataset,
    label_field="detections",
)

# Analyze class distribution
print(view.count_values("detections.detections.label"))
```

## Data Pipeline Stages

### 1. Data Analysis
- Use Voxel51 to visualize dataset and identify distribution shifts
- Quantify class balance, report per-class sample counts
- Flag labeling errors, missing annotations, format mismatches

### 2. Filter & Sample
- Filter by metadata, confidence scores, spatial constraints, annotation quality
- Prefer hard mining over random sampling
- Use Voxel51's built-in sampling rather than loading everything into memory

### 3. Validate
- Check annotation schemas for consistency (label names, bbox formats, mask encoding)
- Verify image dimensions and channel counts — mixed resolutions silently break pipelines
- Flag and fix mismatches before exporting

### 4. Export & Format
- Generate training-ready manifests (JSON/CSV)
- Include train/val/test splits with no leakage
- Track both splits AND versions independently (a split is a partition, a version is a snapshot)

## Common Pitfalls

- **Never modify raw data in place.** Always write to a new directory. Raw sensor logs are immutable source material.
- **Don't assume image dimensions/formats are consistent.** Validate before batch processing.
- **Watch for class imbalance in splits.** A 90/10 class split in validation invalidates metrics. Always report per-class counts.
- **Don't conflate splits with versions.** Track both independently.
- **Memory matters.** Large datasets don't fit in memory. Use streaming loaders, lazy evaluation, and Voxel51's built-in sampling.

## Scope

- **In scope:** Dataset curation, annotation validation, split generation, Voxel51 workflows, data manifests, augmentation pipeline setup.
- **Defer to jetson-gpu-optimization:** Model architecture, training loop optimization, loss function design.
- **Defer to ros2-core-reference:** ROS 2 integration, node architecture.