import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const deployer = accounts.get("deployer")!;
const nonOwner = accounts.get("wallet_2")!;

// Helper function to generate unique student IDs
let studentCounter = 0;
const getUniqueStudentId = () => `STU${String(++studentCounter).padStart(3, '0')}`;

// Helper function to generate unique exam IDs
let examCounter = 0;
const getUniqueExamId = () => `EXAM${String(++examCounter).padStart(3, '0')}`;

describe("Exam Verification System", () => {
    beforeEach(() => {
        // Increment counters to ensure unique IDs across tests
        studentCounter += 10;
        examCounter += 10;
    });
    
    it("should register student successfully", () => {
        const studentId = getUniqueStudentId();
        const studentName = "John Doe";
        
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii(studentId), Cl.stringUtf8(studentName)],
            deployer
        );
        
        expect(result).toBeOk(Cl.bool(true));
        
        // Verify student was actually registered
        const { result: getResult } = simnet.callReadOnlyFn(
            "exam-verification",
            "get-student",
            [Cl.stringAscii(studentId)],
            deployer
        );
        
        expect(getResult).toBeOk(Cl.some(Cl.tuple({
            name: Cl.stringUtf8(studentName),
            "registered-by": Cl.principal(deployer),
            "registration-height": Cl.uint(simnet.blockHeight)
        })));
        
        // Test duplicate registration
        const duplicateResult = simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii(studentId), Cl.stringUtf8("Jane Doe")],
            deployer
        );
        
        expect(duplicateResult.result).toBeErr(Cl.uint(101)); // ERR-STUDENT-EXISTS
    });
    
    it("should store exam result successfully", () => {
        const studentId = getUniqueStudentId();
        const examId = getUniqueExamId();
        const score = 75;
        const maxScore = 100;
        
        // Register student first
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii(studentId), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        // Store result
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.uint(score), Cl.uint(maxScore)],
            deployer
        );
        
        // Should return true for passing grade (75 >= 60)
        expect(result).toBeOk(Cl.bool(true));
        
        // Verify result was stored correctly
        const { result: verifyResult } = simnet.callReadOnlyFn(
            "exam-verification",
            "verify-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId)],
            deployer
        );
        
        expect(verifyResult).toBeOk(Cl.tuple({
            score: Cl.uint(score),
            "max-score": Cl.uint(maxScore),
            passed: Cl.bool(true),
            examiner: Cl.principal(deployer),
            "recorded-height": Cl.uint(simnet.blockHeight)
        }));
    });
    
    it("should handle failing grades correctly", () => {
        const studentId = getUniqueStudentId();
        const examId = getUniqueExamId();
        const score = 50; // Below 60% threshold
        const maxScore = 100;
        
        // Register student first
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii(studentId), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        // Store failing result
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.uint(score), Cl.uint(maxScore)],
            deployer
        );
        
        // Should return false for failing grade (50 < 60)
        expect(result).toBeOk(Cl.bool(false));
        
        // Verify result shows as failed
        const { result: verifyResult } = simnet.callReadOnlyFn(
            "exam-verification",
            "verify-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId)],
            deployer
        );
        
        expect(verifyResult).toBeOk(Cl.tuple({
            score: Cl.uint(score),
            "max-score": Cl.uint(maxScore),
            passed: Cl.bool(false),
            examiner: Cl.principal(deployer),
            "recorded-height": Cl.uint(simnet.blockHeight)
        }));
    });
    
    it("should prevent storing results for non-existent students", () => {
        const nonExistentStudentId = getUniqueStudentId();
        const examId = getUniqueExamId();
        
        // Try to store result without registering student
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(nonExistentStudentId), Cl.stringAscii(examId), Cl.uint(75), Cl.uint(100)],
            deployer
        );
        
        expect(result).toBeErr(Cl.uint(102)); // ERR-STUDENT-NOT-FOUND
    });
    
    it("should prevent invalid scores", () => {
        const studentId = getUniqueStudentId();
        const examId = getUniqueExamId();
        
        // Register student first
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii(studentId), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        // Try to store invalid score (score > max-score)
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.uint(150), Cl.uint(100)],
            deployer
        );
        
        expect(result).toBeErr(Cl.uint(105)); // ERR-INVALID-SCORE
    });
    
    it("should prevent duplicate exam results", () => {
        const studentId = getUniqueStudentId();
        const examId = getUniqueExamId();
        
        // Register student first
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii(studentId), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        // Store result first time
        simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.uint(75), Cl.uint(100)],
            deployer
        );
        
        // Try to store result again
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.uint(85), Cl.uint(100)],
            deployer
        );
        
        expect(result).toBeErr(Cl.uint(103)); // ERR-RESULT-EXISTS
    });
    
    it("should verify exam result not found for non-existent results", () => {
        const nonExistentStudentId = getUniqueStudentId();
        const nonExistentExamId = getUniqueExamId();
        
        // Try to verify non-existent result
        const { result } = simnet.callReadOnlyFn(
            "exam-verification",
            "verify-result",
            [Cl.stringAscii(nonExistentStudentId), Cl.stringAscii(nonExistentExamId)],
            deployer
        );
        
        expect(result).toBeErr(Cl.uint(104)); // ERR-RESULT-NOT-FOUND
    });
    
    it("should issue certificate for passed exam", () => {
        const studentId = getUniqueStudentId();
        const examId = getUniqueExamId();
        
        // Register student and store passing result
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii(studentId), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.uint(85), Cl.uint(100)],
            deployer
        );
        
        // Issue certificate
        const certHash = new Uint8Array(32).fill(1);
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "issue-certificate",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.buffer(certHash)],
            deployer
        );
        
        expect(result).toBeOk(Cl.bool(true));
        
        // Verify certificate was issued
        const { result: getCert } = simnet.callReadOnlyFn(
            "exam-verification",
            "get-certificate",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId)],
            deployer
        );
        
        expect(getCert).toBeOk(Cl.some(Cl.tuple({
            "certificate-hash": Cl.buffer(certHash),
            "issued-by": Cl.principal(deployer),
            "issue-height": Cl.uint(simnet.blockHeight)
        })));
    });
    
    it("should only allow contract owner to issue certificates", () => {
        const studentId = getUniqueStudentId();
        const examId = getUniqueExamId();
        
        // Register student and store passing result
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii(studentId), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.uint(85), Cl.uint(100)],
            deployer
        );
        
        // Try to issue certificate from non-owner account
        const certHash = new Uint8Array(32).fill(1);
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "issue-certificate",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.buffer(certHash)],
            nonOwner  // Not the contract owner
        );
        
        expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });
    
    it("should not issue certificate for failing grades", () => {
        const studentId = getUniqueStudentId();
        const examId = getUniqueExamId();
        
        // Register student and store failing result
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii(studentId), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.uint(50), Cl.uint(100)], // Failing grade
            deployer
        );
        
        // Try to issue certificate for failing grade
        const certHash = new Uint8Array(32).fill(1);
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "issue-certificate",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.buffer(certHash)],
            deployer
        );
        
        expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });
    
    it("should prevent duplicate certificate issuance", () => {
        const studentId = getUniqueStudentId();
        const examId = getUniqueExamId();
        
        // Register student and store passing result
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii(studentId), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.uint(85), Cl.uint(100)],
            deployer
        );
        
        // Issue certificate first time
        const certHash = new Uint8Array(32).fill(1);
        simnet.callPublicFn(
            "exam-verification",
            "issue-certificate",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.buffer(certHash)],
            deployer
        );
        
        // Try to issue certificate again
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "issue-certificate",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId), Cl.buffer(certHash)],
            deployer
        );
        
        expect(result).toBeErr(Cl.uint(106)); // ERR-CERTIFICATE-EXISTS
    });
    
    it("should track result history correctly", () => {
        const studentId = getUniqueStudentId();
        const examId1 = getUniqueExamId();
        const examId2 = getUniqueExamId();
        
        // Register student
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii(studentId), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        // Initial history should be 0
        let { result: historyResult } = simnet.callReadOnlyFn(
            "exam-verification",
            "get-result-history",
            [Cl.stringAscii(studentId)],
            deployer
        );
        
        expect(historyResult).toBeOk(Cl.tuple({
            "attempt-count": Cl.uint(0)
        }));
        
        // Store first result
        simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId1), Cl.uint(85), Cl.uint(100)],
            deployer
        );
        
        // History should be 1
        ({ result: historyResult } = simnet.callReadOnlyFn(
            "exam-verification",
            "get-result-history",
            [Cl.stringAscii(studentId)],
            deployer
        ));
        
        expect(historyResult).toBeOk(Cl.tuple({
            "attempt-count": Cl.uint(1)
        }));
        
        // Store second result
        simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii(studentId), Cl.stringAscii(examId2), Cl.uint(90), Cl.uint(100)],
            deployer
        );
        
        // History should be 2
        ({ result: historyResult } = simnet.callReadOnlyFn(
            "exam-verification",
            "get-result-history",
            [Cl.stringAscii(studentId)],
            deployer
        ));
        
        expect(historyResult).toBeOk(Cl.tuple({
            "attempt-count": Cl.uint(2)
        }));
    });
});
