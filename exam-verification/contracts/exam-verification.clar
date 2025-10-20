;; Exam Result Verification System
;; Independent smart contract for storing and verifying exam results

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-STUDENT-EXISTS (err u101))
(define-constant ERR-STUDENT-NOT-FOUND (err u102))
(define-constant ERR-RESULT-EXISTS (err u103))
(define-constant ERR-RESULT-NOT-FOUND (err u104))
(define-constant ERR-INVALID-SCORE (err u105))
(define-constant ERR-CERTIFICATE-EXISTS (err u106))

;; Data variables
(define-data-var contract-owner principal tx-sender)

;; Data maps
(define-map students
  { student-id: (string-ascii 50) }
  {
    name: (string-utf8 100),
    registered-by: principal,
    registration-height: uint
  }
)

(define-map exam-results
  { student-id: (string-ascii 50), exam-id: (string-ascii 50) }
  {
    score: uint,
    max-score: uint,
    passed: bool,
    examiner: principal,
    recorded-height: uint
  }
)

(define-map certificates
  { student-id: (string-ascii 50), exam-id: (string-ascii 50) }
  {
    certificate-hash: (buff 32),
    issued-by: principal,
    issue-height: uint
  }
)

(define-map result-history
  { student-id: (string-ascii 50) }
  { attempt-count: uint }
)

;; Authorization check
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Public functions

;; 1. Student Registration
(define-public (register-student (student-id (string-ascii 50)) (student-name (string-utf8 100)))
  (let ((existing-student (map-get? students { student-id: student-id })))
    (if (is-some existing-student)
      ERR-STUDENT-EXISTS
      (begin
        (map-set students
          { student-id: student-id }
          {
            name: student-name,
            registered-by: tx-sender,
            registration-height: block-height
          }
        )
        (ok true)
      )
    )
  )
)

;; 2. Store Exam Result
(define-public (store-result 
  (student-id (string-ascii 50)) 
  (exam-id (string-ascii 50))
  (score uint)
  (max-score uint))
  (let (
    (student (map-get? students { student-id: student-id }))
    (existing-result (map-get? exam-results { student-id: student-id, exam-id: exam-id }))
    (passed (>= score (/ (* max-score u60) u100)))
  )
    (asserts! (is-some student) ERR-STUDENT-NOT-FOUND)
    (asserts! (<= score max-score) ERR-INVALID-SCORE)
    (asserts! (is-none existing-result) ERR-RESULT-EXISTS)
    
    (map-set exam-results
      { student-id: student-id, exam-id: exam-id }
      {
        score: score,
        max-score: max-score,
        passed: passed,
        examiner: tx-sender,
        recorded-height: block-height
      }
    )
    
    ;; Update attempt count
    (let ((history (default-to { attempt-count: u0 } 
                    (map-get? result-history { student-id: student-id }))))
      (map-set result-history
        { student-id: student-id }
        { attempt-count: (+ (get attempt-count history) u1) }
      )
    )
    
    (ok passed)
  )
)

;; 3. Verify Exam Result
(define-read-only (verify-result (student-id (string-ascii 50)) (exam-id (string-ascii 50)))
  (match (map-get? exam-results { student-id: student-id, exam-id: exam-id })
    result (ok result)
    ERR-RESULT-NOT-FOUND
  )
)

;; 4. Issue Certificate
(define-public (issue-certificate 
  (student-id (string-ascii 50)) 
  (exam-id (string-ascii 50))
  (cert-hash (buff 32)))
  (let (
    (result (map-get? exam-results { student-id: student-id, exam-id: exam-id }))
    (existing-cert (map-get? certificates { student-id: student-id, exam-id: exam-id }))
  )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-some result) ERR-RESULT-NOT-FOUND)
    (asserts! (get passed (unwrap-panic result)) ERR-NOT-AUTHORIZED)
    (asserts! (is-none existing-cert) ERR-CERTIFICATE-EXISTS)
    
    (map-set certificates
      { student-id: student-id, exam-id: exam-id }
      {
        certificate-hash: cert-hash,
        issued-by: tx-sender,
        issue-height: block-height
      }
    )
    (ok true)
  )
)

;; 5. Get Result History
(define-read-only (get-result-history (student-id (string-ascii 50)))
  (ok (default-to { attempt-count: u0 } 
      (map-get? result-history { student-id: student-id })))
)

;; Read-only functions for verification
(define-read-only (get-student (student-id (string-ascii 50)))
  (ok (map-get? students { student-id: student-id }))
)

(define-read-only (get-certificate (student-id (string-ascii 50)) (exam-id (string-ascii 50)))
  (ok (map-get? certificates { student-id: student-id, exam-id: exam-id }))
)
