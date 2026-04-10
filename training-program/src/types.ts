/**
 * Shared TypeScript interfaces for the Azure DevOps and Terraform Enterprise Training Program.
 * These types model the data structures described in the design document.
 */

// ─── Azure Service ────────────────────────────────────────────────────────────

export interface AzureService {
  name: string;
  service_tier: string;           // e.g. "Standard S1", "vCore General Purpose"
  scaling_requirements: string;   // e.g. "scale out when CPU > 70%"
  cost_considerations: string;    // e.g. "estimated $X/month at peak load"
}

// ─── Problem Statement ────────────────────────────────────────────────────────

export interface ProblemStatement {
  id: string;                          // e.g. "PS1-A"
  title: string;
  business_context: string;
  technical_requirements: string[];
  constraints: string[];
  success_criteria: string[];
  azure_services: AzureService[];
}

// ─── Assessment ───────────────────────────────────────────────────────────────

export interface RubricLevel {
  exemplary: string;    // 4 points
  proficient: string;   // 3 points
  developing: string;   // 2 points
  beginning: string;    // 1 point
}

export interface RubricCriteria {
  criterion: string;
  weight: number;       // percentage, all criteria should sum to 100
  levels: RubricLevel;
}

export interface Question {
  id: string;
  text: string;
  expected_answer?: string;
}

export interface Task {
  id: string;
  description: string;
  validation_steps: string[];
}

export interface Assessment {
  module_id: string;
  knowledge_checks: Question[];   // Theoretical questions
  practical_tasks: Task[];        // Hands-on validation tasks
  rubric: RubricCriteria[];
}

// ─── Interview Question ───────────────────────────────────────────────────────

export type InterviewQuestionType =
  | "conceptual"
  | "scenario"
  | "troubleshooting"
  | "design";

export interface InterviewQuestion {
  module_id: string;
  type: InterviewQuestionType;
  question: string;
  sample_answer: string;
  follow_up_questions: string[];
  evaluation_criteria: string[];
}

// ─── Module ───────────────────────────────────────────────────────────────────

export type Track = "azure-devops" | "terraform";

export interface Module {
  id: string;                          // e.g. "M1", "M7"
  title: string;
  track: Track;
  theory_hours: number;
  practice_hours: number;
  prerequisites: Module[];
  problem_statements: ProblemStatement[];
  assessment: Assessment;
  interview_questions: InterviewQuestion[];
  /** Non-empty summary of theory content (required for structural completeness) */
  theory_content: string;
  /** At least one practical example demonstrating a concept */
  practical_example: string;
  /** At least one hands-on exercise for the learner */
  hands_on_exercise: string;
}

// ─── POC ─────────────────────────────────────────────────────────────────────

export interface Deliverable {
  id: string;
  description: string;
  artifact_path: string;   // relative path to the file/directory
}

export interface ValidationItem {
  id: string;
  description: string;
  expected_state: string;
  validation_command?: string;
}

export interface POC {
  id: string;                      // e.g. "POC1"
  title: string;
  date: string;                    // ISO date string, e.g. "2026-04-07"
  modules_covered: Module[];
  architecture_diagram: string;    // Mermaid diagram source (non-empty when >1 service)
  deliverables: Deliverable[];
  validation_checklist: ValidationItem[];
  estimated_hours: number;
}

// ─── Training Day ─────────────────────────────────────────────────────────────

export interface TrainingDay {
  date: string;           // ISO date string, e.g. "2026-04-07"
  modules: Module[];      // 1–2 modules per day
  poc: POC | null;        // POC exercise if applicable
  objectives: string[];   // Daily learning outcomes
  duration_hours: number; // Total hours for the day
}

// ─── Training Program ─────────────────────────────────────────────────────────

export interface TrainingProgram {
  title: string;
  start_date: string;   // "2026-04-07"
  end_date: string;     // "2026-04-30"
  modules: Module[];
  pocs: POC[];
  schedule: TrainingDay[];
}
