/**
 * Collects Mind browser E2E step outcomes and prints a single summary block at
 * the end of the run (pass / fail / skip / native-only).
 */

export type MindStepStatus = 'pass' | 'fail' | 'skip' | 'native-only';

export interface MindFlowStep {
  id: string;
  phase: string;
  label: string;
  status: MindStepStatus;
  error?: string;
}

const steps: MindFlowStep[] = [];

export function recordMindStep(step: MindFlowStep): void {
  const existing = steps.findIndex((s) => s.id === step.id);
  if (existing >= 0) {
    steps[existing] = step;
    return;
  }
  steps.push(step);
}

export function clearMindSteps(): void {
  steps.length = 0;
}

export function getMindSteps(): readonly MindFlowStep[] {
  return steps;
}

export function printMindE2ESummary(): void {
  const passed = steps.filter((s) => s.status === 'pass');
  const failed = steps.filter((s) => s.status === 'fail');
  const skipped = steps.filter((s) => s.status === 'skip');
  const nativeOnly = steps.filter((s) => s.status === 'native-only');

  const lines: string[] = [
    '',
    '═══════════════════════════════════════════════════════════════',
    '  Airo Mind browser E2E summary',
    '═══════════════════════════════════════════════════════════════',
    `  PASS: ${passed.length}  FAIL: ${failed.length}  SKIP: ${skipped.length}  NATIVE-ONLY: ${nativeOnly.length}`,
    '',
  ];

  for (const step of steps) {
    const tag =
      step.status === 'pass'
        ? '✓'
        : step.status === 'fail'
          ? '✗'
          : step.status === 'native-only'
            ? '◎'
            : '○';
    lines.push(`  ${tag} [${step.phase}] ${step.label}`);
    if (step.error) {
      lines.push(`      → ${step.error}`);
    }
  }

  if (failed.length > 0) {
    lines.push('');
    lines.push('  BLOCKERS (fix before macOS GUI sign-off):');
    for (const step of failed) {
      lines.push(`    • ${step.id}: ${step.error ?? step.label}`);
    }
  }

  if (nativeOnly.length > 0) {
    lines.push('');
    lines.push('  Requires macOS native (not browser):');
    for (const step of nativeOnly) {
      lines.push(`    • ${step.label}`);
    }
  }

  lines.push('═══════════════════════════════════════════════════════════════');
  console.log(lines.join('\n'));
}

export function hasMindBlockers(): boolean {
  return steps.some((s) => s.status === 'fail');
}
