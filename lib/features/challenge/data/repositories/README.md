# EleFit Challenge Repositories

This directory contains the Repository layer for the EleFit Challenge MVP.

## Usage Rules

1. **Single Point of Access**: Repositories are the **only** layer that should directly access Firebase Firestore.
2. **No UI in Repositories**: Repositories should not contain any UI-related code or direct references to `BuildContext`.
3. **Data Mapping**: Repositories use the domain models (`fromFirestore`, `toFirestore`, `toMap`, `fromMap`) to convert between Firestore documents and Dart objects.
4. **Error Handling**: All methods include basic try/catch blocks that rethrow meaningful exceptions for higher layers to handle.
5. **IDs**: Document IDs are mapped to the `id` field of the models.
6. **Business Rules**: Repositories are low-level data access layers. Business logic (e.g., "cannot join a cancelled challenge") should be implemented in a Service layer that uses these repositories.

## Future Enhancements
- Integration with a Service layer for complex business logic.
- Pagination for large list streams.
- Local caching strategies if needed beyond Firestore's default capabilities.
