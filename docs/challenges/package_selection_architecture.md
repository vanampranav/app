# Challenge Package Selection Architecture

This document describes how challenge packages are structured and integrated with Shopify for the EleFit platform.

## Overview

EleFit uses a hybrid approach for challenge packages:
- **Shopify** is the source of truth for all products, inventory, and detailed pricing.
- **Firestore** stores challenge-specific configurations, mapping challenge packages to Shopify variants.

## Firestore Schema

### Collection: `challenges/{challengeId}/packages`

Each document in this subcollection defines a "Challenge Package" offered for a specific challenge.

| Field | Type | Description |
| :--- | :--- | :--- |
| `packageId` | `String` | Unique ID for the package. |
| `name` | `String` | Display name of the package (e.g., "Premium Starter Kit"). |
| `description` | `String` | Description of what the package includes. |
| `packagePrice` | `Double` | The total price to be paid for this package. |
| `currency` | `String` | Currency code (default: "USD"). |
| `displayOrder` | `Int` | Order in which to show the package in UI. |
| `isActive` | `Boolean` | Whether the package is available for selection. |
| `challengeEntryIncluded`| `Boolean` | Whether this package covers the base challenge entry fee. |
| `shopifyVariants` | `List<Map>` | List of Shopify products included in this package. |
| `createdAt` | `Timestamp`| Record creation time. |
| `updatedAt` | `Timestamp`| Last update time. |

#### `shopifyVariants` Structure
```json
{
  "productId": "gid://shopify/Product/12345",
  "variantId": "gid://shopify/ProductVariant/67890",
  "quantity": 1
}
```

## Security Rules

Access to challenge packages is governed by the following `firestore.rules` logic:

- **Participants**: Can `read` packages if they are authenticated and the package `isActive == true`.
- **Admins**: Have full `read`, `create`, `update`, and `delete` permissions for all packages (active or inactive).
- **Public**: No public access (requires `isSignedIn()`).

```rules
match /challenges/{challengeId}/packages/{packageId} {
  allow read: if (isSignedIn() && (resource == null || resource.data.isActive == true)) || isAdmin();
  allow create, update, delete: if isAdmin();
}
```

## Enrollment Flow

1. **Discovery**: User views `ChallengeDetailScreen`.
2. **Intent**: User taps "Join Challenge".
3. **Nickname**: User enters their leaderboard nickname.
4. **Package Selection**: User navigates to `ChallengePackageSelectionScreen`.
    - App fetches all documents from `challenges/{challengeId}/packages` where `isActive == true`.
    - User selects exactly one package.
5. **Enrollment**: `ParticipantEnrollmentService.joinChallenge` is called with the full `ChallengePackage` object.
    - A `ChallengeParticipant` record is created containing a **Snapshot** of the selected package to ensure financial consistency even if the package configuration changes later.
    - Snapshot fields: `selectedPackageId`, `selectedPackageName`, `selectedPackagePrice`, `selectedPackageCurrency`, `selectedShopifyVariantsSnapshot`, `packageSelectedAt`.
    - `paymentStatus` is set to `pending`.
6. **Payment**: User proceeds to submit payment proof or completes an integrated checkout.

## Analytics

The following events are tracked during the package selection process:

- `challenge_package_screen_viewed`: Logged when the selection screen is opened.
- `package_selected`: Logged when the user confirms their selection and taps Continue.
    - Parameters: `challenge_id`, `package_type` (packageId), `price`, `currency`.
- `challenge_join_completed`: Logged after the enrollment is successfully saved to Firestore.

### User Properties
- `challenge_package`: Set to the ID of the last selected package.

## Future Considerations

- **Shopify Integration**: In future phases, the app will fetch real-time product names, images, and current availability from Shopify using the `productId` and `variantId` stored in Firestore.
- **Dynamic Pricing**: Pricing could potentially be resolved dynamically from Shopify variants if complex discounting rules are needed.
- **Admin UI**: An admin screen has been added to the Manage Challenge section to create and edit these package configurations.

## Admin Management Flow

Admins can manage challenge packages through the **Manage Packages** action in the Admin Challenge Detail screen.

### Capabilities
- **List Packages**: View all packages (active and inactive) for a challenge, sorted by `displayOrder`.
- **Create/Edit**: Define name, description, price, currency, and display order.
- **Status Toggle**: Packages can be activated or deactivated. Deactivated packages are hidden from participants during enrollment.
- **Shopify Reference Mapping**: Admins manually enter Shopify Product GIDs and Variant GIDs. 
    - *Warning:* These are references only; the source of truth for availability and detailed attributes remains Shopify.
- **Audit Logging**: All package-related actions (create, update, status toggle) are logged in the `adminAuditLogs` collection.

### Data Integrity
- **Deactivation vs. Deletion**: Hard deletion is discouraged if participants have already enrolled using a package. Admins should use the `isActive` toggle instead to maintain historical snapshot integrity in participant records.
