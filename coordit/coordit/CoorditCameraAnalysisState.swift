import Foundation

#if os(iOS)
struct CoorditCameraAnalysisState: Codable {
    let userID: String
    let draft: CoorditFitLabDraft
    let measurement: CoorditGarmentMeasurement
    let reference: CoorditCameraReference?
    let checkpoint: CoorditFitLabSubmissionCheckpoint
    let recommendation: CoorditFitLabRecommendationResponse?
    let report: CoorditFitLabReportResponse?
    let bundleAnalysisID: String?
}
#endif
