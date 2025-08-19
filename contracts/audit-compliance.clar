;; Audit and Compliance Contract
;; Manages audit trails, compliance reporting, and regulatory documentation

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-AUDIT-NOT-FOUND (err u501))
(define-constant ERR-INVALID-INPUT (err u502))
(define-constant ERR-REPORT-NOT-FOUND (err u503))

;; Data Variables
(define-data-var next-audit-id uint u1)
(define-data-var next-report-id uint u1)

;; Data Maps
(define-map audit-records
  { audit-id: uint }
  {
    equipment-id: uint,
    audit-date: uint,
    auditor: principal,
    audit-type: (string-ascii 50),
    compliance-status: (string-ascii 20),
    findings: (string-ascii 1000),
    recommendations: (string-ascii 1000),
    next-audit-date: uint,
    regulatory-standard: (string-ascii 100)
  }
)

(define-map compliance-reports
  { report-id: uint }
  {
    equipment-id: uint,
    report-date: uint,
    report-type: (string-ascii 50),
    compliance-score: uint,
    violations: uint,
    corrective-actions: (string-ascii 1000),
    generated-by: principal,
    status: (string-ascii 20)
  }
)

(define-map equipment-compliance
  { equipment-id: uint }
  {
    latest-audit-id: uint,
    compliance-rating: uint,
    last-audit-date: uint,
    next-required-audit: uint,
    violation-count: uint
  }
)

(define-map regulatory-requirements
  { equipment-type: (string-ascii 50) }
  {
    required-standards: (string-ascii 200),
    audit-frequency-days: uint,
    mandatory-certifications: (string-ascii 200)
  }
)

;; Read-only functions
(define-read-only (get-audit-record (audit-id uint))
  (map-get? audit-records { audit-id: audit-id })
)

(define-read-only (get-compliance-report (report-id uint))
  (map-get? compliance-reports { report-id: report-id })
)

(define-read-only (get-equipment-compliance (equipment-id uint))
  (map-get? equipment-compliance { equipment-id: equipment-id })
)

(define-read-only (get-regulatory-requirements (equipment-type (string-ascii 50)))
  (map-get? regulatory-requirements { equipment-type: equipment-type })
)

(define-read-only (get-next-audit-id)
  (var-get next-audit-id)
)

(define-read-only (get-next-report-id)
  (var-get next-report-id)
)

(define-read-only (is-audit-due (equipment-id uint) (current-date uint))
  (match (get-equipment-compliance equipment-id)
    compliance (<= (get next-required-audit compliance) current-date)
    true
  )
)

;; Public functions
(define-public (create-audit-record
  (equipment-id uint)
  (audit-date uint)
  (audit-type (string-ascii 50))
  (compliance-status (string-ascii 20))
  (findings (string-ascii 1000))
  (recommendations (string-ascii 1000))
  (next-audit-date uint)
  (regulatory-standard (string-ascii 100))
)
  (let
    (
      (audit-id (var-get next-audit-id))
      (current-compliance (get-equipment-compliance equipment-id))
    )
    ;; Validate inputs
    (asserts! (> audit-date u0) ERR-INVALID-INPUT)
    (asserts! (> (len audit-type) u0) ERR-INVALID-INPUT)
    (asserts! (> (len compliance-status) u0) ERR-INVALID-INPUT)
    (asserts! (> next-audit-date audit-date) ERR-INVALID-INPUT)

    ;; Create audit record
    (map-set audit-records
      { audit-id: audit-id }
      {
        equipment-id: equipment-id,
        audit-date: audit-date,
        auditor: tx-sender,
        audit-type: audit-type,
        compliance-status: compliance-status,
        findings: findings,
        recommendations: recommendations,
        next-audit-date: next-audit-date,
        regulatory-standard: regulatory-standard
      }
    )

    ;; Update equipment compliance
    (let
      (
        (compliance-rating (if (is-eq compliance-status "compliant") u100 u50))
        (violation-count (if (is-eq compliance-status "non-compliant") u1 u0))
      )
      (map-set equipment-compliance
        { equipment-id: equipment-id }
        {
          latest-audit-id: audit-id,
          compliance-rating: compliance-rating,
          last-audit-date: audit-date,
          next-required-audit: next-audit-date,
          violation-count: (+ (default-to u0 (get violation-count current-compliance)) violation-count)
        }
      )
    )

    ;; Increment next ID
    (var-set next-audit-id (+ audit-id u1))

    (ok audit-id)
  )
)

(define-public (generate-compliance-report
  (equipment-id uint)
  (report-date uint)
  (report-type (string-ascii 50))
  (compliance-score uint)
  (violations uint)
  (corrective-actions (string-ascii 1000))
)
  (let
    (
      (report-id (var-get next-report-id))
    )
    ;; Validate inputs
    (asserts! (> report-date u0) ERR-INVALID-INPUT)
    (asserts! (> (len report-type) u0) ERR-INVALID-INPUT)
    (asserts! (<= compliance-score u100) ERR-INVALID-INPUT)

    ;; Create compliance report
    (map-set compliance-reports
      { report-id: report-id }
      {
        equipment-id: equipment-id,
        report-date: report-date,
        report-type: report-type,
        compliance-score: compliance-score,
        violations: violations,
        corrective-actions: corrective-actions,
        generated-by: tx-sender,
        status: "active"
      }
    )

    ;; Increment next ID
    (var-set next-report-id (+ report-id u1))

    (ok report-id)
  )
)

(define-public (set-regulatory-requirements
  (equipment-type (string-ascii 50))
  (required-standards (string-ascii 200))
  (audit-frequency-days uint)
  (mandatory-certifications (string-ascii 200))
)
  (begin
    ;; Check authorization
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    ;; Validate inputs
    (asserts! (> (len equipment-type) u0) ERR-INVALID-INPUT)
    (asserts! (> audit-frequency-days u0) ERR-INVALID-INPUT)

    ;; Set requirements
    (map-set regulatory-requirements
      { equipment-type: equipment-type }
      {
        required-standards: required-standards,
        audit-frequency-days: audit-frequency-days,
        mandatory-certifications: mandatory-certifications
      }
    )

    (ok true)
  )
)

(define-public (update-audit-status (audit-id uint) (new-status (string-ascii 20)))
  (let
    (
      (audit (unwrap! (get-audit-record audit-id) ERR-AUDIT-NOT-FOUND))
    )
    ;; Check authorization
    (asserts! (or (is-eq tx-sender (get auditor audit)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)

    ;; Update audit
    (map-set audit-records
      { audit-id: audit-id }
      (merge audit { compliance-status: new-status })
    )

    (ok true)
  )
)

(define-public (update-report-status (report-id uint) (new-status (string-ascii 20)))
  (let
    (
      (report (unwrap! (get-compliance-report report-id) ERR-REPORT-NOT-FOUND))
    )
    ;; Check authorization
    (asserts! (or (is-eq tx-sender (get generated-by report)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)

    ;; Update report
    (map-set compliance-reports
      { report-id: report-id }
      (merge report { status: new-status })
    )

    (ok true)
  )
)
