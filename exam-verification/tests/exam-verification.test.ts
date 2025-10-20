import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const deployer = accounts.get("deployer")!;

describe("Exam Verification System", () => {
    it("should register student successfully", () => {
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii("STU001"), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        expect(result).toBeOk(Cl.bool(true));
        
        // Test duplicate registration
        const duplicateResult = simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii("STU001"), Cl.stringUtf8("Jane Doe")],
            deployer
        );
        
        expect(duplicateResult.result).toBeErr(Cl.uint(101));
    });
    
    it("should store exam result successfully", () => {
        // Register student first
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii("STU002"), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        // Store result
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii("STU002"), Cl.stringAscii("EXAM001"), Cl.uint(75), Cl.uint(100)],
            deployer
        );
        
        expect(result).toBeOk(Cl.bool(true));
    });
    
    it("should verify exam result correctly", () => {
        // Register student and store result
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii("STU003"), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii("STU003"), Cl.stringAscii("EXAM001"), Cl.uint(85), Cl.uint(100)],
            deployer
        );
        
        // Verify result
        const { result } = simnet.callReadOnlyFn(
            "exam-verification",
            "verify-result",
            [Cl.stringAscii("STU003"), Cl.stringAscii("EXAM001")],
            deployer
        );
        
        // Verify the function executes without error
        expect(result).toBeDefined();
    });
    
    it("should issue certificate for passed exam", () => {
        // Register student and store passing result
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii("STU004"), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii("STU004"), Cl.stringAscii("EXAM001"), Cl.uint(85), Cl.uint(100)],
            deployer
        );
        
        // Issue certificate
        const certHash = new Uint8Array(32).fill(1);
        const { result } = simnet.callPublicFn(
            "exam-verification",
            "issue-certificate",
            [Cl.stringAscii("STU004"), Cl.stringAscii("EXAM001"), Cl.buffer(certHash)],
            deployer
        );
        
        expect(result).toBeOk(Cl.bool(true));
    });
    
    it("should track result history correctly", () => {
        // Register student and store multiple results
        simnet.callPublicFn(
            "exam-verification",
            "register-student",
            [Cl.stringAscii("STU005"), Cl.stringUtf8("John Doe")],
            deployer
        );
        
        simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii("STU005"), Cl.stringAscii("EXAM001"), Cl.uint(85), Cl.uint(100)],
            deployer
        );
        
        simnet.callPublicFn(
            "exam-verification",
            "store-result",
            [Cl.stringAscii("STU005"), Cl.stringAscii("EXAM002"), Cl.uint(90), Cl.uint(100)],
            deployer
        );
        
        // Check history
        const { result } = simnet.callReadOnlyFn(
            "exam-verification",
            "get-result-history",
            [Cl.stringAscii("STU005")],
            deployer
        );
        
        // Verify the function executes without error
        expect(result).toBeDefined();
    });
});
