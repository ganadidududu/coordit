import { buildUserFeedbackFitProfile } from "../fit/feedback-fit-profile";
import { supabaseFitReassessmentRepository } from "./fit-reassessment.repository";
import { createFitReassessmentService } from "./fit-reassessment.service";

export const fitReassessmentService = createFitReassessmentService({
  repository: supabaseFitReassessmentRepository,
  buildFeedbackProfile: buildUserFeedbackFitProfile,
  now: () => new Date()
});
