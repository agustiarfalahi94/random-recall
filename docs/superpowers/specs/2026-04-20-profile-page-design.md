# Profile Page Implementation Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:writing-plans (recommended) or superpowers:executing-plans to implement this spec task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a profile page as the 4th tab in the bottom navigation bar, allowing users to view and edit their account information, manage authentication settings, and delete their account.

**Architecture:**
- New screen: `lib/screens/profile/profile_screen.dart` — displays user info with edit capabilities
- Firebase Storage integration for profile picture storage with local compression/caching
- Conditional UI rendering based on auth provider (email vs. Google) and subscription status
- Re-authentication flow for sensitive operations (delete account, change password)

**Tech Stack:**
- Flutter (image_picker for camera/gallery, cached_network_image for image caching)
- Firebase Storage (profile picture storage)
- Firebase Authentication (password change, account deletion, re-auth)
- Local SQLite/SharedPreferences (profile data caching)

---

## Bottom Navigation Bar Integration

**Current structure:**
- Tab 1: Home
- Tab 2: Questions
- Tab 3: Analytics
- Tab 4 (NEW): Profile

**Changes to `lib/screens/home/home_screen.dart`:**
- Add Profile icon to BottomNavigationBar (Icon: `Icons.person_rounded`)
- Add ProfileScreen to NavigationDestination list
- Update index/page management to handle 4 tabs

---

## Profile Page Sections

### Header Section
- **Profile Picture Display:**
  - Circular image (e.g., 120px diameter) centered at top
  - Default placeholder if no picture set (generic person icon)
  - Tappable to open edit dialog
  - Sourced from Firebase Storage (`/users/{userId}/profile_picture.jpg`)
  - Cached locally using `cached_network_image` package

### Editable Fields Section
All fields below the profile picture, in a scrollable column:

1. **Name** (editable text field)
   - Current value from local SQLite or SharedPreferences
   - Synced to Firebase Firestore `users/{userId}` document
   - Max 50 characters
   - Validation: non-empty

2. **Phone Number** (editable text field)
   - Current value from local SQLite or SharedPreferences
   - Synced to Firebase Firestore `users/{userId}` document
   - Optional field (can be empty)
   - Validation: valid phone format (basic regex or libphonenumber)
   - Max 20 characters

3. **Email** (read-only display)
   - Sourced from `FirebaseAuth.instance.currentUser?.email`
   - Always greyed out / disabled
   - Shows login method indicator: "Email" or "Google Account"

4. **Subscription Status** (read-only badge)
   - Sourced from local SharedPreferences (`is_premium` flag)
   - Badge styling: green for Premium, gray for Free
   - Text: "Premium" or "Free"

### Account Management Section
Located below editable fields, in a separate visual group:

1. **Change Password Button** (if email user)
   - Conditionally shown ONLY for email-authenticated users
   - Hidden for Google sign-in users (they manage password in Google Account)
   - Taps to open password change dialog (current password + new password + confirm)
   - Uses Firebase `updatePassword()` API

2. **Delete Account Button** (red/danger styling)
   - Shown for all users
   - Two-step deletion:
     - Step 1: Warning dialog "Are you sure? Account deletion is permanent. All your data will be deleted."
     - Step 2: Re-authentication:
       - **Email users:** Prompt for current password
       - **Google users:** Trigger Google sign-in re-auth
     - Step 3 (on success): Call Firebase `FirebaseAuth.instance.currentUser?.delete()`
     - Delete all user data from Firestore and Storage (backup cascade delete)

---

## Profile Picture Editing Flow

**User taps on profile picture:**
1. Open bottom sheet with two options:
   - "Take Photo" (camera)
   - "Choose from Gallery" (gallery picker)
2. User selects source
3. Image picker opens (camera or gallery)
4. User captures/selects image
5. Image is processed:
   - Resize to 512×512px (square crop)
   - Compress JPEG to 80% quality (balance size vs. visual quality)
   - Save compressed version to local file cache
6. Upload to Firebase Storage at path: `/users/{userId}/profile_picture.jpg`
7. Update local database with new image URL
8. Refresh UI to show new picture
9. Show toast: "Profile picture updated"

**Error handling:**
- If upload fails: show error toast, keep local cache as fallback
- If permission denied: show permission request prompt

---

## Data Model

### Local Storage (SQLite / SharedPreferences)
```
user_profile:
  - user_id (string, primary key)
  - name (string, max 50 chars)
  - phone_number (string, max 20 chars, nullable)
  - profile_picture_url (string, nullable) — Firebase Storage URL
  - profile_picture_local_path (string, nullable) — cached image path
  - updated_at (timestamp)
```

### Firebase Firestore
```
users/{userId}:
  - name (string)
  - phone_number (string, optional)
  - profile_picture_url (string, optional)
  - is_premium (boolean)
  - created_at (timestamp)
  - updated_at (timestamp)
```

### Firebase Storage
```
/users/{userId}/profile_picture.jpg — compressed image (512×512, 80% JPEG quality)
```

---

## Localization Strings

### English (`app_en.arb`)
```json
{
  "profilePageTitle": "Profile",
  "profilePictureLabel": "Profile Picture",
  "nameLabel": "Name",
  "phoneLabel": "Phone Number",
  "emailLabel": "Email",
  "subscriptionStatusLabel": "Subscription Status",
  "subscriptionStatusPremium": "Premium",
  "subscriptionStatusFree": "Free",
  "changePasswordButton": "Change Password",
  "deleteAccountButton": "Delete Account",
  "deleteAccountWarning": "Are you sure? Account deletion is permanent. All your data will be deleted.",
  "deleteAccountConfirm": "Delete Account",
  "deleteAccountCancel": "Cancel",
  "profilePictureSourceCamera": "Take Photo",
  "profilePictureSourceGallery": "Choose from Gallery",
  "profilePictureUpdated": "Profile picture updated",
  "profilePictureUpdateFailed": "Failed to update profile picture",
  "profileUpdateSuccess": "Profile updated successfully",
  "profileUpdateFailed": "Failed to update profile",
  "passwordChangedSuccess": "Password changed successfully",
  "passwordChangedFailed": "Failed to change password",
  "accountDeletedSuccess": "Account deleted successfully",
  "accountDeleteFailed": "Failed to delete account",
  "googleAccountLabel": "Google Account",
  "emailAccountLabel": "Email"
}
```

### Indonesian (`app_id.arb`)
```json
{
  "profilePageTitle": "Profil",
  "profilePictureLabel": "Foto Profil",
  "nameLabel": "Nama",
  "phoneLabel": "Nomor Telepon",
  "emailLabel": "Email",
  "subscriptionStatusLabel": "Status Langganan",
  "subscriptionStatusPremium": "Premium",
  "subscriptionStatusFree": "Gratis",
  "changePasswordButton": "Ubah Kata Sandi",
  "deleteAccountButton": "Hapus Akun",
  "deleteAccountWarning": "Apakah Anda yakin? Penghapusan akun bersifat permanen. Semua data Anda akan dihapus.",
  "deleteAccountConfirm": "Hapus Akun",
  "deleteAccountCancel": "Batal",
  "profilePictureSourceCamera": "Ambil Foto",
  "profilePictureSourceGallery": "Pilih dari Galeri",
  "profilePictureUpdated": "Foto profil diperbarui",
  "profilePictureUpdateFailed": "Gagal memperbarui foto profil",
  "profileUpdateSuccess": "Profil berhasil diperbarui",
  "profileUpdateFailed": "Gagal memperbarui profil",
  "passwordChangedSuccess": "Kata sandi berhasil diubah",
  "passwordChangedFailed": "Gagal mengubah kata sandi",
  "accountDeletedSuccess": "Akun berhasil dihapus",
  "accountDeleteFailed": "Gagal menghapus akun",
  "googleAccountLabel": "Akun Google",
  "emailAccountLabel": "Email"
}
```

---

## Files Modified / Created

1. **`lib/screens/profile/profile_screen.dart`** — NEW (main profile page screen)
2. **`lib/screens/home/home_screen.dart`** — modify BottomNavigationBar to add Profile tab
3. **`lib/core/services/profile_service.dart`** — NEW (business logic for profile operations)
4. **`lib/l10n/app_en.arb`** — add profile-related strings
5. **`lib/l10n/app_id.arb`** — add profile-related strings (Indonesian)
6. **`pubspec.yaml`** — add `image_picker` and `cached_network_image` dependencies
7. **`CHANGELOG.md`** — document profile page feature

---

## Testing Strategy

- **Unit:** Test profile service methods (image compression, upload, field validation)
- **UI:** Manual testing on both Android and iOS:
  - Edit name, phone (verify Firestore sync)
  - Upload profile picture from camera/gallery (verify Firebase Storage + local cache)
  - Change password (email users only)
  - Delete account (with re-auth flow for both email and Google)
  - Subscription status display (update SharedPreferences and verify badge changes)
- **Firebase:** Verify data appears in Firestore and Storage
- **Localization:** Test in both English and Indonesian

---

## Not in Scope

- Profile picture cropping tool (simple resize/compress only)
- Bio/description field (keep MVP focused)
- Social media links or profile visibility settings
- Profile sharing or public profiles
- Two-factor authentication setup (covered separately if needed)
