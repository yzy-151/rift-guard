"""Keep a durable native benchmark ledger; run after all serial variants finish."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
directory = root / "qa" / "performance-20261006"
variants = ["baseline", "baseline-repeat", "warning-cache", "shared-warning-geometry", "integration", "skill-dispatch-disabled", "skill-dispatch-enabled", "skill-dispatch-disabled-final", "skill-dispatch-enabled-final", "skill-dispatch-disabled-revision3", "skill-dispatch-enabled-revision3"]
revision3_path = directory / "skill-dispatch-enabled-revision3" / "native.json"
revision3_report = json.loads(revision3_path.read_text(encoding="utf-8")) if revision3_path.exists() else None
current_sources = {
    path: hashlib.sha256((root / "game" / path.removeprefix("res://")).read_bytes()).hexdigest()
    if (root / "game" / path.removeprefix("res://")).exists() else None
    for path in revision3_report["source_files"]
} if revision3_report else {}
revision3_mismatches = [path for path, checksum in current_sources.items() if checksum != revision3_report["source_files"][path]]
revision3_source_current = bool(revision3_report) and not revision3_mismatches
version_metadata_exception = None
if revision3_mismatches == ["res://project.godot"]:
    current_project = (root / "game" / "project.godot").read_bytes()
    # Only this explicitly authorized version change is allowed. Reconstructing
    # the complete measured bytes rules out any simultaneous rendering change.
    measured_project = current_project.replace(b'config/version="2026.10.6.3"', b'config/version="2026.10.6.2"')
    if measured_project != current_project and hashlib.sha256(measured_project).hexdigest() == revision3_report["source_files"]["res://project.godot"]:
        version_metadata_exception = {
            "path": "res://project.godot",
            "field": "application/config/version",
            "measured_value": "2026.10.6.2",
            "current_value": "2026.10.6.3",
            "measured_file_sha256": revision3_report["source_files"]["res://project.godot"],
            "current_file_sha256": current_sources["res://project.godot"],
            "exact_previous_file_reconstruction_verified": True,
            "other_source_files_unchanged": len(current_sources) - 1,
            "authorization": "root explicitly confirmed version-only metadata exception; no rendering/window/performance setting change",
        }
revision3_source_equivalent = revision3_source_current or version_metadata_exception is not None
measured_manifest_rehash = hashlib.sha256(json.dumps(revision3_report["source_files"], separators=(",", ":"), sort_keys=True).encode()).hexdigest() if revision3_report else None
current_manifest_sha256 = hashlib.sha256(json.dumps(current_sources, separators=(",", ":"), sort_keys=True).encode()).hexdigest() if revision3_report and measured_manifest_rehash == revision3_report["source_sha256"] else None
ledger = {
    "fixture_sha256": hashlib.sha256((directory / "frozen.var").read_bytes()).hexdigest(),
    "rules": {
        "renderer": "default GL Compatibility / RTX 5060 Ti",
        "window": "1920x1080, logical 1280x720",
        "vsync": "disabled consistently for benchmark only",
        "input": "frozen 51/80 mixed enemies, three characters, Lv11 at 211sec, real 90/120 piercing shots",
        "samples": "30 warmup + 180 frames per case; two repeats for each size; serial processes; no ffmpeg",
        "max_variants": 6,
        "max_minutes": 40,
        "numeric_changes": "ordinary campaign balancing occurred separately; fixture arrays and build are restored from frozen.var",
        "hp_metric": "legacy damage_to_enemies field is net HP change, includes healing/buff growth and may be negative",
        "correctness": "same final HP delta, projectile impact count, enemy count, elapsed and frozen file checksum",
    },
    "variants": {},
    "promoted_performance_variant": "warning-cache",
    # A source-matched technical holdout is not aesthetic approval.
    "final_product_holdout": "skill-dispatch-enabled-revision3" if revision3_source_equivalent else None,
    "latest_measured_variant": "skill-dispatch-enabled-revision3" if revision3_report else ("skill-dispatch-enabled-final" if (directory / "skill-dispatch-enabled-final" / "native.json").exists() else "skill-dispatch-enabled"),
    "release_status": "revision3 technically measured with documented version-only metadata exception; aesthetics pending master review" if version_metadata_exception else ("revision3 frozen source technically measured; aesthetics pending master review" if revision3_source_current else "current source not matched to latest technical holdout"),
    "visual_acceptance": "pending master review",
    "revision3_source_matches_current_files": revision3_source_current,
    "revision3_source_equivalent_with_authorized_metadata_exception": revision3_source_equivalent,
    "version_metadata_exception": version_metadata_exception,
    "measured_source_manifest_sha256": revision3_report["source_sha256"] if revision3_report else None,
    "current_source_manifest_sha256": current_manifest_sha256,
    "decisions": {
        "baseline": "two repeats of the original runtime source snapshot",
        "baseline-repeat": "repeat uncached endpoint algorithm to verify stability after profiling counters",
        "warning-cache": "promoted: 18-pixel ray endpoints cached with exact origin/direction/geometry validation; screenshots byte-identical",
        "shared-warning-geometry": "rejected: saves a small warning subphase amount but no repeatable whole-frame improvement; reverted",
        "integration": "historical atlas rendering holdout; subsequently rejected and superseded by current skill-specific dispatcher",
        "skill-dispatch-disabled": "current frozen product source; explicit new-dispatcher opt-out; original visual fallback, not a new optimization candidate",
        "skill-dispatch-enabled": "earlier skill-specific dispatcher enabled; same source/input as disabled; Rift Commander charge and crowded projectiles measured, not all 17 skill releases or the double-Boss encounter",
        "skill-dispatch-disabled-final": "intermediate source after Galio wind material refinement; paired visual fallback; historical folder suffix final is not a release assertion",
        "skill-dispatch-enabled-final": "intermediate source before latest user-requested Galio wind restoration; same input/source as paired disabled-final; not final deliverable validation",
        "skill-dispatch-disabled-revision3": "revision3 source-matched visual fallback; original Galio wind restored, other skills revised; no simulation change",
        "skill-dispatch-enabled-revision3": "revision3 technical holdout, aesthetics still pending master review; same source/input as paired disabled-revision3; Commander charge/crowded real shots, not all 17 releases or double-Boss pressure",
    },
}
baseline = json.loads((directory / "baseline" / "native.json").read_text(encoding="utf-8"))
disabled_path = directory / "skill-dispatch-disabled" / "native.json"
disabled = json.loads(disabled_path.read_text(encoding="utf-8")) if disabled_path.exists() else None
final_disabled_path = directory / "skill-dispatch-disabled-final" / "native.json"
final_disabled = json.loads(final_disabled_path.read_text(encoding="utf-8")) if final_disabled_path.exists() else None
revision3_disabled_path = directory / "skill-dispatch-disabled-revision3" / "native.json"
revision3_disabled = json.loads(revision3_disabled_path.read_text(encoding="utf-8")) if revision3_disabled_path.exists() else None
for variant in variants:
    result_file = directory / variant / "native.json"
    if not result_file.exists():
        continue
    result = json.loads(result_file.read_text(encoding="utf-8"))
    paired_disabled = revision3_disabled if variant.endswith("-revision3") else (final_disabled if variant.endswith("-final") else disabled)
    summary = {}
    for case, row in result["cases"].items():
        metric = row["metrics"]
        summary[case] = {
            "metrics": metric,
            "correctness_matches_baseline": row["correctness"] == baseline["cases"][case]["correctness"],
            "fixture_matches_baseline": row["fixture_sha256"] == baseline["cases"][case]["fixture_sha256"],
            "wall_p50_improvement_percent": round(100 * (1 - metric["wall_frame_ms"]["p50"] / baseline["cases"][case]["metrics"]["wall_frame_ms"]["p50"]), 2),
        }
        if paired_disabled is not None and variant in ["skill-dispatch-enabled", "skill-dispatch-enabled-final", "skill-dispatch-enabled-revision3"]:
            summary[case]["correctness_matches_same_source_disabled"] = row["correctness"] == paired_disabled["cases"][case]["correctness"]
            summary[case]["enabled_minus_disabled_frame_p50_ms"] = round(metric["wall_frame_ms"]["p50"] - paired_disabled["cases"][case]["metrics"]["wall_frame_ms"]["p50"], 3)
    pngs = {}
    for count in [51, 80]:
        native_png = directory / variant / f"enemies-{count}.png"
        if native_png.exists():
            pngs[str(count)] = {
                "sha256": hashlib.sha256(native_png.read_bytes()).hexdigest(),
                "byte_identical_to_baseline": native_png.read_bytes() == (directory / "baseline" / native_png.name).read_bytes(),
            }
    ledger["variants"][variant] = {"cases": summary, "native_screenshots": pngs}
    if "source_sha256" in result:
        ledger["variants"][variant]["source_sha256"] = result["source_sha256"]
        ledger["variants"][variant]["source_unchanged_during_measurement"] = result["source_unchanged"]
        ledger["variants"][variant]["source_files_count"] = len(result["source_files"])
        ledger["variants"][variant]["boss_vfx_enabled"] = result["boss_vfx_enabled"]
        ledger["variants"][variant]["warning_reference"] = result["warning_reference"]
        ledger["variants"][variant]["stderr_bytes"] = (directory / f"{variant}.stderr").stat().st_size
        if paired_disabled is not None:
            ledger["variants"][variant]["same_source_as_disabled"] = result["source_sha256"] == paired_disabled["source_sha256"]
    for case, data in summary.items():
        metric = data["metrics"]
        print(variant, case, "frame", metric["wall_frame_ms"], "draw", metric["draw_cpu_ms"], "warnings", metric["draw_telegraphs_ms"], "correct", data["correctness_matches_baseline"])
gate = directory / "warning-cache-correctness.json"
if gate.exists():
    ledger["warning_endpoint_gate"] = json.loads(gate.read_text(encoding="utf-8"))
(directory / "ledger.json").write_text(json.dumps(ledger, ensure_ascii=False, indent=2), encoding="utf-8")
