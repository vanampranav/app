# Admin Authorization & Security Setup

The Challenge MVP implements a role-based access control (RBAC) system. 

## 1. Role Definitions
Users can have one of the following roles:
- `user` (Default): Access to participate in challenges and view their own logs.
- `admin`: Full access to manage challenges, participants, payments, and submissions.
- `superAdmin`: Same as admin, intended for system owners.

## 2. Admin Privileges
Admin access is granted if a user document in Firestore (`users/{uid}`) satisfies **any** of these conditions:
- `isAdmin == true`
- `role == "admin"`
- `role == "superAdmin"`

## 3. Manual Initial Setup
Since there is no "Create Admin" UI for security reasons, the first admin must be manually designated in the Firebase Console:

1. Go to **Firestore Database** in the Firebase Console.
2. Navigate to the `users` collection.
3. Find your `userId` document (or create it if it doesn't exist).
4. Add the following fields:
   - `isAdmin`: `boolean` -> `true`
   - `role`: `string` -> `"admin"`

## 4. UI Protection
- Use `AdminGuard(child: MyScreen())` to protect entire screens.
- Use `context.watch<AuthService>().isUserAdmin` to conditionally show/hide buttons or menu items.

## 5. Backend Security
The `firestore.rules` file in the project root must be deployed to your Firebase project to enforce these restrictions at the database level.
