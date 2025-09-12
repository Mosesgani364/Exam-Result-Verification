(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_UNIVERSITY (err u103))
(define-constant ERR_INVALID_STUDENT (err u104))
(define-constant ERR_INVALID_CERTIFICATE (err u105))
(define-constant ERR_EXPIRED_CERTIFICATE (err u106))
(define-constant ERR_CERTIFICATE_REVOKED (err u107))
(define-constant ERR_INVALID_GRADE (err u108))
(define-constant ERR_INVALID_EXAM_DATE (err u109))
(define-constant ERR_DUPLICATE_CERTIFICATE (err u110))
(define-constant ERR_INVALID_TRANSCRIPT (err u111))
(define-constant ERR_TRANSCRIPT_NOT_FOUND (err u112))
(define-constant ERR_COURSE_NOT_FOUND (err u113))
(define-constant ERR_TRANSFER_NOT_FOUND (err u114))
(define-constant ERR_TRANSFER_ALREADY_PROCESSED (err u115))
(define-constant ERR_SELF_TRANSFER (err u116))

(define-map universities
    { university-id: uint }
    {
        name: (string-ascii 100),
        admin: principal,
        accreditation-number: (string-ascii 50),
        country: (string-ascii 50),
        established-year: uint,
        is-active: bool,
        registration-block: uint,
    }
)

(define-map students
    { student-id: (string-ascii 50) }
    {
        name: (string-ascii 100),
        date-of-birth: (string-ascii 10),
        nationality: (string-ascii 50),
        student-address: principal,
        registration-block: uint,
        university-id: uint,
    }
)

(define-map certificates
    { certificate-id: (string-ascii 100) }
    {
        student-id: (string-ascii 50),
        university-id: uint,
        degree-type: (string-ascii 50),
        major: (string-ascii 100),
        grade: (string-ascii 10),
        graduation-date: (string-ascii 10),
        exam-date: (string-ascii 10),
        certificate-hash: (string-ascii 64),
        issue-block: uint,
        expiry-block: uint,
        is-revoked: bool,
        issuer: principal,
    }
)

(define-map certificate-verification-requests
    { request-id: uint }
    {
        certificate-id: (string-ascii 100),
        requester: principal,
        request-block: uint,
        status: (string-ascii 20),
        verifier: (optional principal),
    }
)

(define-map exam-results
    { exam-id: (string-ascii 100) }
    {
        student-id: (string-ascii 50),
        university-id: uint,
        subject: (string-ascii 100),
        exam-date: (string-ascii 10),
        score: uint,
        max-score: uint,
        grade: (string-ascii 10),
        examiner: principal,
        verification-status: (string-ascii 20),
    }
)

(define-map transcripts
    { transcript-id: (string-ascii 100) }
    {
        student-id: (string-ascii 50),
        university-id: uint,
        semester: (string-ascii 20),
        academic-year: (string-ascii 10),
        total-credits: uint,
        gpa: (string-ascii 10),
        status: (string-ascii 20),
        issue-date: (string-ascii 10),
        issuer: principal,
        is-final: bool,
    }
)

(define-map transcript-courses
    {
        transcript-id: (string-ascii 100),
        course-code: (string-ascii 20),
    }
    {
        course-name: (string-ascii 100),
        credits: uint,
        grade: (string-ascii 10),
        semester: (string-ascii 20),
    }
)

(define-map certificate-transfer-requests
    { transfer-id: uint }
    {
        certificate-id: (string-ascii 100),
        current-owner: principal,
        new-owner: principal,
        request-block: uint,
        status: (string-ascii 20),
        approved-by-owner: bool,
        approved-by-recipient: bool,
    }
)

(define-map certificate-owners
    { certificate-id: (string-ascii 100) }
    { owner: principal }
)

(define-data-var next-university-id uint u1)
(define-data-var next-request-id uint u1)
(define-data-var next-transfer-id uint u1)
(define-data-var verification-fee uint u1000000)
(define-data-var certificate-validity-period uint u525600)

(define-public (register-university
        (name (string-ascii 100))
        (accreditation-number (string-ascii 50))
        (country (string-ascii 50))
        (established-year uint)
    )
    (let ((university-id (var-get next-university-id)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> established-year u1800) ERR_INVALID_UNIVERSITY)
        (asserts! (< established-year u2025) ERR_INVALID_UNIVERSITY)
        (asserts!
            (is-none (map-get? universities { university-id: university-id }))
            ERR_ALREADY_EXISTS
        )
        (map-set universities { university-id: university-id } {
            name: name,
            admin: tx-sender,
            accreditation-number: accreditation-number,
            country: country,
            established-year: established-year,
            is-active: true,
            registration-block: stacks-block-height,
        })
        (var-set next-university-id (+ university-id u1))
        (ok university-id)
    )
)

(define-public (register-student
        (student-id (string-ascii 50))
        (name (string-ascii 100))
        (date-of-birth (string-ascii 10))
        (nationality (string-ascii 50))
        (university-id uint)
    )
    (let ((university (unwrap! (map-get? universities { university-id: university-id })
            ERR_NOT_FOUND
        )))
        (asserts! (get is-active university) ERR_INVALID_UNIVERSITY)
        (asserts! (is-none (map-get? students { student-id: student-id }))
            ERR_ALREADY_EXISTS
        )
        (map-set students { student-id: student-id } {
            name: name,
            date-of-birth: date-of-birth,
            nationality: nationality,
            student-address: tx-sender,
            registration-block: stacks-block-height,
            university-id: university-id,
        })
        (ok true)
    )
)

(define-public (issue-certificate
        (certificate-id (string-ascii 100))
        (student-id (string-ascii 50))
        (university-id uint)
        (degree-type (string-ascii 50))
        (major (string-ascii 100))
        (grade (string-ascii 10))
        (graduation-date (string-ascii 10))
        (exam-date (string-ascii 10))
        (certificate-hash (string-ascii 64))
    )
    (let (
            (university (unwrap! (map-get? universities { university-id: university-id })
                ERR_NOT_FOUND
            ))
            (student (unwrap! (map-get? students { student-id: student-id }) ERR_NOT_FOUND))
            (issue-block stacks-block-height)
            (expiry-block (+ issue-block (var-get certificate-validity-period)))
        )
        (asserts! (is-eq tx-sender (get admin university)) ERR_UNAUTHORIZED)
        (asserts! (get is-active university) ERR_INVALID_UNIVERSITY)
        (asserts! (is-eq (get university-id student) university-id)
            ERR_INVALID_STUDENT
        )
        (asserts!
            (is-none (map-get? certificates { certificate-id: certificate-id }))
            ERR_DUPLICATE_CERTIFICATE
        )
        (map-set certificates { certificate-id: certificate-id } {
            student-id: student-id,
            university-id: university-id,
            degree-type: degree-type,
            major: major,
            grade: grade,
            graduation-date: graduation-date,
            exam-date: exam-date,
            certificate-hash: certificate-hash,
            issue-block: issue-block,
            expiry-block: expiry-block,
            is-revoked: false,
            issuer: tx-sender,
        })
        (map-set certificate-owners { certificate-id: certificate-id } { owner: (get student-address student) })
        (ok true)
    )
)

(define-public (record-exam-result
        (exam-id (string-ascii 100))
        (student-id (string-ascii 50))
        (university-id uint)
        (subject (string-ascii 100))
        (exam-date (string-ascii 10))
        (score uint)
        (max-score uint)
        (grade (string-ascii 10))
    )
    (let ((university (unwrap! (map-get? universities { university-id: university-id })
            ERR_NOT_FOUND
        )))
        (asserts! (is-eq tx-sender (get admin university)) ERR_UNAUTHORIZED)
        (asserts! (get is-active university) ERR_INVALID_UNIVERSITY)
        (asserts! (is-some (map-get? students { student-id: student-id }))
            ERR_INVALID_STUDENT
        )
        (asserts! (<= score max-score) ERR_INVALID_GRADE)
        (asserts! (> max-score u0) ERR_INVALID_GRADE)
        (map-set exam-results { exam-id: exam-id } {
            student-id: student-id,
            university-id: university-id,
            subject: subject,
            exam-date: exam-date,
            score: score,
            max-score: max-score,
            grade: grade,
            examiner: tx-sender,
            verification-status: "verified",
        })
        (ok true)
    )
)

(define-public (request-certificate-verification (certificate-id (string-ascii 100)))
    (let (
            (certificate (unwrap! (map-get? certificates { certificate-id: certificate-id })
                ERR_NOT_FOUND
            ))
            (request-id (var-get next-request-id))
        )
        (asserts! (not (get is-revoked certificate)) ERR_CERTIFICATE_REVOKED)
        (asserts! (< stacks-block-height (get expiry-block certificate))
            ERR_EXPIRED_CERTIFICATE
        )
        (try! (stx-transfer? (var-get verification-fee) tx-sender CONTRACT_OWNER))
        (map-set certificate-verification-requests { request-id: request-id } {
            certificate-id: certificate-id,
            requester: tx-sender,
            request-block: stacks-block-height,
            status: "pending",
            verifier: none,
        })
        (var-set next-request-id (+ request-id u1))
        (ok request-id)
    )
)

(define-public (verify-certificate-request
        (request-id uint)
        (is-valid bool)
    )
    (let (
            (request (unwrap!
                (map-get? certificate-verification-requests { request-id: request-id })
                ERR_NOT_FOUND
            ))
            (certificate-id (get certificate-id request))
            (certificate (unwrap! (map-get? certificates { certificate-id: certificate-id })
                ERR_NOT_FOUND
            ))
            (university (unwrap!
                (map-get? universities { university-id: (get university-id certificate) })
                ERR_NOT_FOUND
            ))
        )
        (asserts! (is-eq tx-sender (get admin university)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status request) "pending") ERR_INVALID_CERTIFICATE)
        (map-set certificate-verification-requests { request-id: request-id }
            (merge request {
                status: (if is-valid
                    "verified"
                    "invalid"
                ),
                verifier: (some tx-sender),
            })
        )
        (ok true)
    )
)

(define-public (revoke-certificate (certificate-id (string-ascii 100)))
    (let (
            (certificate (unwrap! (map-get? certificates { certificate-id: certificate-id })
                ERR_NOT_FOUND
            ))
            (university (unwrap!
                (map-get? universities { university-id: (get university-id certificate) })
                ERR_NOT_FOUND
            ))
        )
        (asserts! (is-eq tx-sender (get admin university)) ERR_UNAUTHORIZED)
        (asserts! (not (get is-revoked certificate)) ERR_CERTIFICATE_REVOKED)
        (map-set certificates { certificate-id: certificate-id }
            (merge certificate { is-revoked: true })
        )
        (ok true)
    )
)

(define-public (update-verification-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set verification-fee new-fee)
        (ok true)
    )
)

(define-public (deactivate-university (university-id uint))
    (let ((university (unwrap! (map-get? universities { university-id: university-id })
            ERR_NOT_FOUND
        )))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set universities { university-id: university-id }
            (merge university { is-active: false })
        )
        (ok true)
    )
)

(define-public (initiate-certificate-transfer
        (certificate-id (string-ascii 100))
        (new-owner principal)
    )
    (let (
            (certificate (unwrap! (map-get? certificates { certificate-id: certificate-id })
                ERR_NOT_FOUND
            ))
            (current-owner-record (unwrap!
                (map-get? certificate-owners { certificate-id: certificate-id })
                ERR_NOT_FOUND
            ))
            (current-owner (get owner current-owner-record))
            (transfer-id (var-get next-transfer-id))
        )
        (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
        (asserts! (not (is-eq current-owner new-owner)) ERR_SELF_TRANSFER)
        (asserts! (not (get is-revoked certificate)) ERR_CERTIFICATE_REVOKED)
        (asserts! (< stacks-block-height (get expiry-block certificate))
            ERR_EXPIRED_CERTIFICATE
        )
        (map-set certificate-transfer-requests { transfer-id: transfer-id } {
            certificate-id: certificate-id,
            current-owner: current-owner,
            new-owner: new-owner,
            request-block: stacks-block-height,
            status: "pending",
            approved-by-owner: true,
            approved-by-recipient: false,
        })
        (var-set next-transfer-id (+ transfer-id u1))
        (ok transfer-id)
    )
)

(define-public (accept-certificate-transfer (transfer-id uint))
    (let (
            (transfer-request (unwrap!
                (map-get? certificate-transfer-requests { transfer-id: transfer-id })
                ERR_TRANSFER_NOT_FOUND
            ))
            (certificate-id (get certificate-id transfer-request))
            (new-owner (get new-owner transfer-request))
        )
        (asserts! (is-eq tx-sender new-owner) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status transfer-request) "pending")
            ERR_TRANSFER_ALREADY_PROCESSED
        )
        (map-set certificate-transfer-requests { transfer-id: transfer-id }
            (merge transfer-request {
                status: "completed",
                approved-by-recipient: true,
            })
        )
        (map-set certificate-owners { certificate-id: certificate-id } { owner: new-owner })
        (ok true)
    )
)

(define-public (reject-certificate-transfer (transfer-id uint))
    (let (
            (transfer-request (unwrap!
                (map-get? certificate-transfer-requests { transfer-id: transfer-id })
                ERR_TRANSFER_NOT_FOUND
            ))
            (new-owner (get new-owner transfer-request))
        )
        (asserts! (is-eq tx-sender new-owner) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status transfer-request) "pending")
            ERR_TRANSFER_ALREADY_PROCESSED
        )
        (map-set certificate-transfer-requests { transfer-id: transfer-id }
            (merge transfer-request { status: "rejected" })
        )
        (ok true)
    )
)

(define-public (cancel-certificate-transfer (transfer-id uint))
    (let (
            (transfer-request (unwrap!
                (map-get? certificate-transfer-requests { transfer-id: transfer-id })
                ERR_TRANSFER_NOT_FOUND
            ))
            (current-owner (get current-owner transfer-request))
        )
        (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status transfer-request) "pending")
            ERR_TRANSFER_ALREADY_PROCESSED
        )
        (map-set certificate-transfer-requests { transfer-id: transfer-id }
            (merge transfer-request { status: "cancelled" })
        )
        (ok true)
    )
)

(define-read-only (get-certificate (certificate-id (string-ascii 100)))
    (map-get? certificates { certificate-id: certificate-id })
)

(define-read-only (get-student (student-id (string-ascii 50)))
    (map-get? students { student-id: student-id })
)

(define-read-only (get-university (university-id uint))
    (map-get? universities { university-id: university-id })
)

(define-read-only (get-exam-result (exam-id (string-ascii 100)))
    (map-get? exam-results { exam-id: exam-id })
)

(define-read-only (get-verification-request (request-id uint))
    (map-get? certificate-verification-requests { request-id: request-id })
)

(define-read-only (is-certificate-valid (certificate-id (string-ascii 100)))
    (match (map-get? certificates { certificate-id: certificate-id })
        certificate (and
            (not (get is-revoked certificate))
            (< stacks-block-height (get expiry-block certificate))
        )
        false
    )
)

(define-read-only (get-verification-fee)
    (var-get verification-fee)
)

(define-read-only (verify-certificate-authenticity
        (certificate-id (string-ascii 100))
        (expected-hash (string-ascii 64))
    )
    (match (map-get? certificates { certificate-id: certificate-id })
        certificate (and
            (is-eq (get certificate-hash certificate) expected-hash)
            (not (get is-revoked certificate))
            (< stacks-block-height (get expiry-block certificate))
        )
        false
    )
)

(define-read-only (get-certificate-owner (certificate-id (string-ascii 100)))
    (map-get? certificate-owners { certificate-id: certificate-id })
)

(define-read-only (get-transfer-request (transfer-id uint))
    (map-get? certificate-transfer-requests { transfer-id: transfer-id })
)

(define-read-only (is-certificate-transferable (certificate-id (string-ascii 100)))
    (match (map-get? certificates { certificate-id: certificate-id })
        certificate (and
            (not (get is-revoked certificate))
            (< stacks-block-height (get expiry-block certificate))
            (is-some (map-get? certificate-owners { certificate-id: certificate-id }))
        )
        false
    )
)

(define-public (issue-transcript
        (transcript-id (string-ascii 100))
        (student-id (string-ascii 50))
        (university-id uint)
        (semester (string-ascii 20))
        (academic-year (string-ascii 10))
        (total-credits uint)
        (gpa (string-ascii 10))
        (issue-date (string-ascii 10))
        (is-final bool)
    )
    (let (
            (university (unwrap! (map-get? universities { university-id: university-id })
                ERR_NOT_FOUND
            ))
            (student (unwrap! (map-get? students { student-id: student-id }) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get admin university)) ERR_UNAUTHORIZED)
        (asserts! (get is-active university) ERR_INVALID_UNIVERSITY)
        (asserts! (is-eq (get university-id student) university-id)
            ERR_INVALID_STUDENT
        )
        (asserts!
            (is-none (map-get? transcripts { transcript-id: transcript-id }))
            ERR_INVALID_TRANSCRIPT
        )
        (map-set transcripts { transcript-id: transcript-id } {
            student-id: student-id,
            university-id: university-id,
            semester: semester,
            academic-year: academic-year,
            total-credits: total-credits,
            gpa: gpa,
            status: "active",
            issue-date: issue-date,
            issuer: tx-sender,
            is-final: is-final,
        })
        (ok true)
    )
)

(define-public (add-course-to-transcript
        (transcript-id (string-ascii 100))
        (course-code (string-ascii 20))
        (course-name (string-ascii 100))
        (credits uint)
        (grade (string-ascii 10))
        (semester (string-ascii 20))
    )
    (let (
            (transcript (unwrap! (map-get? transcripts { transcript-id: transcript-id })
                ERR_TRANSCRIPT_NOT_FOUND
            ))
            (university (unwrap!
                (map-get? universities { university-id: (get university-id transcript) })
                ERR_NOT_FOUND
            ))
        )
        (asserts! (is-eq tx-sender (get admin university)) ERR_UNAUTHORIZED)
        (asserts! (get is-active university) ERR_INVALID_UNIVERSITY)
        (asserts! (is-eq (get status transcript) "active") ERR_INVALID_TRANSCRIPT)
        (asserts! (> credits u0) ERR_INVALID_GRADE)
        (map-set transcript-courses {
            transcript-id: transcript-id,
            course-code: course-code,
        } {
            course-name: course-name,
            credits: credits,
            grade: grade,
            semester: semester,
        })
        (ok true)
    )
)

(define-public (finalize-transcript (transcript-id (string-ascii 100)))
    (let (
            (transcript (unwrap! (map-get? transcripts { transcript-id: transcript-id })
                ERR_TRANSCRIPT_NOT_FOUND
            ))
            (university (unwrap!
                (map-get? universities { university-id: (get university-id transcript) })
                ERR_NOT_FOUND
            ))
        )
        (asserts! (is-eq tx-sender (get admin university)) ERR_UNAUTHORIZED)
        (asserts! (get is-active university) ERR_INVALID_UNIVERSITY)
        (asserts! (is-eq (get status transcript) "active") ERR_INVALID_TRANSCRIPT)
        (map-set transcripts { transcript-id: transcript-id }
            (merge transcript {
                status: "finalized",
                is-final: true,
            })
        )
        (ok true)
    )
)

(define-read-only (get-transcript (transcript-id (string-ascii 100)))
    (map-get? transcripts { transcript-id: transcript-id })
)

(define-read-only (get-transcript-course
        (transcript-id (string-ascii 100))
        (course-code (string-ascii 20))
    )
    (map-get? transcript-courses {
        transcript-id: transcript-id,
        course-code: course-code,
    })
)

(define-read-only (is-transcript-finalized (transcript-id (string-ascii 100)))
    (match (map-get? transcripts { transcript-id: transcript-id })
        transcript (is-eq (get status transcript) "finalized")
        false
    )
)
