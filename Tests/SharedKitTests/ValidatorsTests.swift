import Foundation
@testable import SharedKit
import Testing

@Suite("Validators")
struct ValidatorsTests {
    // MARK: - Email Validation

    @Suite("Email")
    struct EmailTests {
        @Test("valid email returns .valid")
        func validEmail() {
            let result = Validators.validateEmail("user@example.com")
            #expect(result.isValid)
        }

        @Test("email with subdomain returns .valid")
        func emailWithSubdomain() {
            let result = Validators.validateEmail("user@mail.example.com")
            #expect(result.isValid)
        }

        @Test("email with plus addressing returns .valid")
        func emailWithPlusAddressing() {
            let result = Validators.validateEmail("user+tag@example.com")
            #expect(result.isValid)
        }

        @Test("email with dots in local part returns .valid")
        func emailWithDots() {
            let result = Validators.validateEmail("first.last@example.com")
            #expect(result.isValid)
        }

        @Test("empty email returns required error")
        func emptyEmail() {
            let result = Validators.validateEmail("")
            #expect(!result.isValid)
            #expect(result.errorMessage == "Email is required")
        }

        @Test("whitespace-only email returns required error")
        func whitespaceOnlyEmail() {
            let result = Validators.validateEmail("   ")
            #expect(!result.isValid)
            #expect(result.errorMessage == "Email is required")
        }

        @Test("email without @ returns invalid format")
        func emailWithoutAt() {
            let result = Validators.validateEmail("not-an-email")
            #expect(!result.isValid)
            #expect(result.errorMessage == "Please enter a valid email address")
        }

        @Test("email without domain returns invalid format")
        func emailWithoutDomain() {
            let result = Validators.validateEmail("user@")
            #expect(!result.isValid)
        }

        @Test("email without TLD returns invalid format")
        func emailWithoutTLD() {
            let result = Validators.validateEmail("user@example")
            #expect(!result.isValid)
        }

        @Test("email with single char TLD returns invalid format")
        func emailWithSingleCharTLD() {
            let result = Validators.validateEmail("user@example.c")
            #expect(!result.isValid)
        }
    }

    // MARK: - Password Validation

    @Suite("Password")
    struct PasswordTests {
        @Test("valid password returns .valid")
        func validPassword() {
            let result = Validators.validatePassword("password123")
            #expect(result.isValid)
        }

        @Test("exactly 8 characters returns .valid with default min")
        func exactlyMinLength() {
            let result = Validators.validatePassword("12345678")
            #expect(result.isValid)
        }

        @Test("empty password returns required error")
        func emptyPassword() {
            let result = Validators.validatePassword("")
            #expect(!result.isValid)
            #expect(result.errorMessage == "Password is required")
        }

        @Test("whitespace-only password returns required error")
        func whitespaceOnlyPassword() {
            let result = Validators.validatePassword("   ")
            #expect(!result.isValid)
            #expect(result.errorMessage == "Password is required")
        }

        @Test("too short password returns length error")
        func tooShort() {
            let result = Validators.validatePassword("short", minLength: 8)
            #expect(!result.isValid)
            #expect(result.errorMessage == "Password must be at least 8 characters")
        }

        @Test("custom min length enforced")
        func customMinLength() {
            let tooShort = Validators.validatePassword("ab", minLength: 3)
            #expect(!tooShort.isValid)

            let justRight = Validators.validatePassword("abc", minLength: 3)
            #expect(justRight.isValid)
        }

        @Test("single-argument overload uses default min length of 8")
        func singleArgumentOverload() {
            let tooShort = Validators.validatePassword("1234567")
            #expect(!tooShort.isValid)

            let valid = Validators.validatePassword("12345678")
            #expect(valid.isValid)
        }
    }

    // MARK: - Name Validation

    @Suite("Name")
    struct NameTests {
        @Test("valid name returns .valid")
        func validName() {
            let result = Validators.validateName("John")
            #expect(result.isValid)
        }

        @Test("empty name returns required error")
        func emptyName() {
            let result = Validators.validateName("")
            #expect(!result.isValid)
            #expect(result.errorMessage == "Name is required")
        }

        @Test("single character name fails with default min of 2")
        func tooShort() {
            let result = Validators.validateName("J")
            #expect(!result.isValid)
            #expect(result.errorMessage == "Name must be at least 2 characters")
        }

        @Test("custom field name appears in error messages")
        func customFieldName() {
            let result = Validators.validateName("", fieldName: "Username")
            #expect(result.errorMessage == "Username is required")

            let short = Validators.validateName("A", fieldName: "Username", minLength: 3)
            #expect(short.errorMessage == "Username must be at least 3 characters")
        }

        @Test("single-argument overload uses defaults")
        func singleArgumentOverload() {
            let result = Validators.validateName("Jo")
            #expect(result.isValid)
        }
    }

    // MARK: - Password Confirmation

    @Suite("PasswordConfirmation")
    struct PasswordConfirmationTests {
        @Test("matching passwords return .valid")
        func matching() {
            let result = Validators.validatePasswordConfirmation("secret", "secret")
            #expect(result.isValid)
        }

        @Test("mismatched passwords return error")
        func mismatched() {
            let result = Validators.validatePasswordConfirmation("secret", "different")
            #expect(!result.isValid)
            #expect(result.errorMessage == "Passwords do not match")
        }

        @Test("empty strings match")
        func emptyStringsMatch() {
            let result = Validators.validatePasswordConfirmation("", "")
            #expect(result.isValid)
        }
    }

    // MARK: - Minimum Length Validation

    @Suite("MinLength")
    struct MinLengthTests {
        @Test("text meeting minimum is valid")
        func meetsMinimum() {
            let result = Validators.validateMinLength("Hello, this is a description.", fieldName: "Description", min: 10)
            #expect(result.isValid)
        }

        @Test("text below minimum is invalid")
        func belowMinimum() {
            let result = Validators.validateMinLength("Short", fieldName: "Bio", min: 10)
            #expect(!result.isValid)
            #expect(result.errorMessage == "Bio must be at least 10 characters")
        }

        @Test("empty text returns required error")
        func emptyText() {
            let result = Validators.validateMinLength("", fieldName: "Bio", min: 10)
            #expect(!result.isValid)
            #expect(result.errorMessage == "Bio is required")
        }

        @Test("single-argument overload uses Description and 10")
        func singleArgumentOverload() {
            let result = Validators.validateMinLength("Short")
            #expect(!result.isValid)
            #expect(result.errorMessage == "Description must be at least 10 characters")
        }
    }

    // MARK: - Birth Year Validation

    @Suite("BirthYear")
    struct BirthYearTests {
        @Test("valid birth year returns .valid")
        func validYear() {
            let result = Validators.validateBirthYear("1990")
            #expect(result.isValid)
        }

        @Test("empty birth year is valid (optional field)")
        func emptyIsValid() {
            let result = Validators.validateBirthYear("")
            #expect(result.isValid)
        }

        @Test("whitespace-only birth year is valid (optional field)")
        func whitespaceOnlyIsValid() {
            let result = Validators.validateBirthYear("   ")
            #expect(result.isValid)
        }

        @Test("year before minimum returns error")
        func tooOld() {
            let result = Validators.validateBirthYear("1800", minYear: 1900)
            #expect(!result.isValid)
            #expect(result.errorMessage == "Birth year must be 1900 or later")
        }

        @Test("future year returns error")
        func futureYear() {
            let result = Validators.validateBirthYear("2099")
            #expect(!result.isValid)
            #expect(result.errorMessage == "Birth year cannot be in the future")
        }

        @Test("non-numeric string returns error")
        func nonNumeric() {
            let result = Validators.validateBirthYear("abc")
            #expect(!result.isValid)
            #expect(result.errorMessage == "Birth year must be a valid year")
        }

        @Test("current year is valid")
        func currentYear() {
            let year = Calendar.current.component(.year, from: Date())
            let result = Validators.validateBirthYear("\(year)")
            #expect(result.isValid)
        }

        @Test("minimum year boundary is valid")
        func minimumYearBoundary() {
            let result = Validators.validateBirthYear("1900", minYear: 1900)
            #expect(result.isValid)
        }
    }

    // MARK: - ValidationResult

    @Suite("ValidationResult")
    struct ValidationResultTests {
        @Test("valid case has isValid true and nil errorMessage")
        func validCase() {
            let result = ValidationResult.valid
            #expect(result.isValid)
            #expect(result.errorMessage == nil)
        }

        @Test("invalid case has isValid false and errorMessage set")
        func invalidCase() {
            let result = ValidationResult.invalid("some error")
            #expect(!result.isValid)
            #expect(result.errorMessage == "some error")
        }
    }
}
