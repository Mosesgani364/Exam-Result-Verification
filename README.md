# 🎓 Exam Result Verification Smart Contract

A blockchain-based system for universities to publish and verify academic certificates and exam results on the Stacks blockchain.

## 🚀 Overview

This smart contract enables universities to:
- Register and manage their institutional profiles
- Issue verifiable digital certificates
- Record and verify exam results
- Provide tamper-proof certificate verification
- Manage student records securely

## 📋 Features

### 🏛️ University Management
- University registration with accreditation details
- Admin role-based access control
- University activation/deactivation

### 👨‍🎓 Student Management
- Student registration with personal details
- Link students to their respective universities
- Maintain student academic records

### 📜 Certificate Management
- Issue digital certificates with cryptographic hashes
- Certificate expiration and revocation system
- Real-time certificate validity checking

### 📊 Exam Results
- Record exam scores and grades
- Link results to students and universities
- Verification status tracking

### 🔍 Verification System
- Pay-to-verify certificate authenticity
- University-validated verification requests
- Comprehensive certificate validation

## 🛠️ Contract Functions

### Public Functions

#### University Functions
- `register-university` - Register a new university
- `deactivate-university` - Deactivate a university (admin only)

#### Student Functions
- `register-student` - Register a new student

#### Certificate Functions
- `issue-certificate` - Issue a new certificate
- `revoke-certificate` - Revoke an existing certificate
- `request-certificate-verification` - Request verification (requires fee)
- `verify-certificate-request` - Verify a certificate request

#### Exam Functions
- `record-exam-result` - Record exam results

#### Administrative Functions
- `update-verification-fee` - Update verification fee (admin only)

### Read-Only Functions

- `get-certificate` - Retrieve certificate details
- `get-student` - Retrieve student information
- `get-university` - Retrieve university information
- `get-exam-result` - Retrieve exam result details
- `get-verification-request` - Retrieve verification request status
- `is-certificate-valid` - Check if certificate is valid
- `verify-certificate-authenticity` - Verify certificate hash
- `get-verification-fee` - Get current verification fee

## 🔧 Usage Examples

### Register a University
```clarity
(contract-call? .exam-result-verification register-university
  "Harvard University"
  "HARV-2024-001"
  "United States"
  u1636
)
```

### Register a Student
```clarity
(contract-call? .exam-result-verification register-student
  "STU-2024-001"
  "John Doe"
  "1995-05-15"
  "American"
  u1
)
```

### Issue a Certificate
```clarity
(contract-call? .exam-result-verification issue-certificate
  "CERT-2024-001"
  "STU-2024-001"
  u1
  "Bachelor of Science"
  "Computer Science"
  "A"
  "2024-05-15"
  "2024-05-10"
  "abc123def456..."
)
```

### Verify a Certificate
```clarity
(contract-call? .exam-result-verification request-certificate-verification
  "CERT-2024-001"
)
```

## 💰 Fees

- **Verification Fee**: 1 STX (configurable by admin)
- **Certificate Validity**: 525,600 blocks (~1 year)

## 🔒 Security Features

- Role-based access control
- Certificate expiration system
- Revocation capabilities
- Cryptographic hash verification
- Input validation and error handling

## 🚨 Error Codes

- `u100` - Unauthorized access
- `u101` - Already exists
- `u102` - Not found
- `u103` - Invalid university
- `u104` - Invalid student
- `u105` - Invalid certificate
- `u106` - Expired certificate
- `u107` - Certificate revoked
- `u108` - Invalid grade
- `u109` - Invalid exam date
- `u110` - Duplicate certificate

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```

## 📦 Deployment

Deploy to testnet:
```bash
clarinet deploy --testnet
```

Deploy to mainnet:
```bash
clarinet deploy --mainnet
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.
