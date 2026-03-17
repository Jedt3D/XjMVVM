# MVVM Architecture — Knowledge Base

> **Project:** Xojo Web Application (MVVM Pattern)
> **Last Updated:** 2026-03-11

---

## 1. What is MVVM?

**Model-View-ViewModel (MVVM)** is a software architectural pattern that cleanly separates an application's **User Interface (UI)** from its **business logic and data**. It was originally designed by Microsoft architects Ken Cooper and Ted Peters for WPF/Silverlight applications and has since become a cornerstone pattern in modern UI development.

MVVM solves the classic problem of tightly coupled UI code — where business logic, data access, and rendering are all mixed together — by introducing three distinct layers that each have a single, well-defined responsibility.

---

## 2. The Three Core Layers

```
┌──────────┐     Data Binding / Notifications      ┌───────────────┐
│          │ ────────────────────────────────────▶  │               │
│   VIEW   │                                        │  VIEWMODEL    │
│          │ ◀────────────────────────────────────  │               │
└──────────┘     Commands / User Actions            └───────┬───────┘
                                                            │
                                                   Reads & Updates
                                                            │
                                                    ┌───────▼───────┐
                                                    │               │
                                                    │    MODEL      │
                                                    │               │
                                                    └───────────────┘
```

### 2.1 Model
The **Model** represents the data and business logic of the application. It is completely independent of the UI.

**Responsibilities:**
- Holds application data (entities, domain objects)
- Implements business rules and validation
- Handles data persistence (database calls, API calls)
- Is unaware of the View and ViewModel

**In Xojo:** Plain Xojo Classes containing properties and methods. No reference to WebPage controls or UI elements.

```
Example Model Classes:
  - UserModel         → user data + validation
  - ProductModel      → product data + business rules
  - DatabaseService   → data access logic
  - APIClient         → external service calls
```

---

### 2.2 View
The **View** is the UI layer. It displays data and captures user input, but contains **no business logic**.

**Responsibilities:**
- Renders data provided by the ViewModel
- Captures user interactions (clicks, input)
- Forwards all actions to the ViewModel (never processes them itself)
- Updates itself when the ViewModel state changes

**In Xojo:** WebPage classes and their controls (WebTextField, WebButton, WebListBox, etc.)

**Key rule:** A View should be "dumb" — it should not know where data comes from or what happens when a button is clicked. It just displays and delegates.

---

### 2.3 ViewModel
The **ViewModel** is the bridge between Model and View. It is the most important component in MVVM.

**Responsibilities:**
- Exposes data from the Model in a form the View can easily display
- Holds UI state (loading indicators, error messages, selected items)
- Handles all commands triggered by user interactions
- Notifies the View when data changes (via callbacks, events, or binding)
- Never directly references View controls

**In Xojo:** Xojo Classes that act as the logic layer for each WebPage.

```
Example ViewModel Classes:
  - LoginViewModel    → manages login state, calls AuthModel
  - ProductListVM     → manages product list display and filtering
  - DashboardVM       → aggregates data for the dashboard page
```

---

## 3. Data Flow Rules

MVVM follows a strict, one-directional data ownership model:

```
User Action (e.g., button click)
    │
    ▼
View → calls method on ViewModel
    │
    ▼
ViewModel → reads/writes Model
    │
    ▼
Model → updates its data
    │
    ▼
ViewModel → detects change, updates its exposed properties
    │
    ▼
View → re-reads ViewModel properties, refreshes UI
```

**Golden rules:**
- **Data flows DOWN:** Model → ViewModel → View
- **Events flow UP:** View → ViewModel → Model
- The Model never knows about the ViewModel
- The ViewModel never knows about the View
- The View only knows about the ViewModel (never the Model directly)

---

## 4. Implementing MVVM in Xojo Web

Xojo does not have a built-in MVVM framework, but the pattern can be cleanly applied using Xojo's OOP capabilities.

### 4.1 Folder/Namespace Structure

```
Project
├── Models/
│   ├── UserModel
│   ├── ProductModel
│   └── DatabaseService
│
├── ViewModels/
│   ├── LoginViewModel
│   ├── ProductListViewModel
│   └── DashboardViewModel
│
└── Views/  (WebPages)
    ├── LoginPage
    ├── ProductListPage
    └── DashboardPage
```

### 4.2 ViewModel ↔ View Communication in Xojo

Since Xojo Web doesn't have automatic data binding, use one of these approaches:

**Option A — Callback/Delegate Pattern**
The ViewModel holds a delegate reference to a method in the View. When the ViewModel's state changes, it calls the delegate to notify the View to refresh.

**Option B — Observer/Event Pattern**
Use Xojo's built-in event system or implement a custom Observer (Notification Center) pattern. The ViewModel raises an event; the View listens and refreshes itself.

**Option C — Pull on Demand**
The View explicitly calls ViewModel methods to get current data whenever a user action completes (simpler but less reactive).

### 4.3 Practical Example Structure

```
' === MODEL ===
Class UserModel
  Property Username As String
  Property Email As String

  Function Validate() As Boolean
    Return Username.Length > 0 And Email.Contains("@")
  End Function
End Class


' === VIEWMODEL ===
Class LoginViewModel
  Property CurrentUser As UserModel
  Property ErrorMessage As String
  Property IsLoading As Boolean

  ' Callback so ViewModel can notify the View
  Property OnStateChanged As Delegate

  Sub Login(username As String, password As String)
    Me.IsLoading = True
    NotifyView()

    ' Call model/service
    Dim result As Boolean = AuthService.Authenticate(username, password)

    If result Then
      Me.CurrentUser = New UserModel
      Me.CurrentUser.Username = username
    Else
      Me.ErrorMessage = "Invalid credentials"
    End If

    Me.IsLoading = False
    NotifyView()
  End Sub

  Private Sub NotifyView()
    If OnStateChanged <> Nil Then
      OnStateChanged.Invoke()
    End If
  End Sub
End Class


' === VIEW (WebPage) ===
WebPage: LoginPage
  ' Reference to ViewModel
  Property VM As LoginViewModel

  Sub Opening()
    VM = New LoginViewModel
    VM.OnStateChanged = AddressOf RefreshUI
  End Sub

  Sub LoginButton_Action()
    VM.Login(UsernameField.Text, PasswordField.Text)
  End Sub

  Sub RefreshUI()
    If VM.IsLoading Then
      StatusLabel.Text = "Logging in..."
    ElseIf VM.ErrorMessage <> "" Then
      ErrorLabel.Text = VM.ErrorMessage
    Else
      ' Navigate to next page
    End If
  End Sub
End WebPage
```

---

## 5. MVVM vs Other Patterns

| Aspect | MVC | MVP | MVVM |
|---|---|---|---|
| **Mediator** | Controller | Presenter | ViewModel |
| **View awareness** | Controller knows View | Presenter knows View (via interface) | ViewModel does NOT know View |
| **Data binding** | Manual | Manual | Declarative/automatic |
| **Testability** | Medium | High | High |
| **Complexity** | Low | Medium | Medium-High |
| **Best for** | Web (server-side) | Desktop/mobile | Data-heavy UIs, reactive apps |

**When to use MVVM over MVC in Xojo Web:**
- UI has complex state (loading states, conditional visibility, live updates)
- Multiple views share the same data/logic
- You want to unit test business logic without instantiating WebPages
- The UI is data-driven and changes frequently based on user interactions

---

## 6. Key Design Principles

### 6.1 Single Responsibility
Each class does one thing:
- Model classes only know about data and rules
- ViewModel classes only know about UI state and commands
- View classes only know about rendering

### 6.2 Separation of Concerns
- UI designers can work on Views independently of developers working on ViewModels
- Business logic changes don't require touching UI code
- UI redesigns don't require touching business logic

### 6.3 Dependency Direction
Dependencies always point inward:
```
View → ViewModel → Model
```
Never the reverse.

### 6.4 Keep the ViewModel UI-Agnostic
The ViewModel should never import or reference WebPage controls, WebTextField, WebButton, etc. It should only work with primitive types (String, Integer, Boolean) and domain objects (Model classes).

---

## 7. Common Pitfalls to Avoid

| Pitfall | Why it's a problem | Fix |
|---|---|---|
| Logic in View (WebPage) | Makes UI hard to test and reuse | Move all logic to ViewModel |
| ViewModel referencing View controls | Tight coupling, breaks testability | Use callbacks/delegates instead |
| Model containing UI state | Pollutes business logic with UI concerns | Keep UI state in ViewModel only |
| One giant ViewModel | Hard to maintain, violates SRP | Break into focused ViewModels per feature |
| Direct Model access from View | Skips the ViewModel layer | Always route through ViewModel |

---

## 8. Testability

One of MVVM's biggest advantages is **testability without UI**:

- **Model classes** can be tested with pure unit tests — no WebPage needed
- **ViewModel classes** can be tested by calling methods directly and checking property values — no WebPage needed
- **View classes** are the only thing that needs manual or integration testing

This means the majority of your application logic can be covered by automated tests.

---

## 9. Xojo-Specific Notes

- **Session scope:** In Xojo Web, each user has their own `Session`. ViewModels should be scoped to the Session or WebPage, not the App class, to avoid shared-state bugs across users.
- **App class:** Should only contain truly application-wide resources (configuration, shared services). Do NOT put user-specific state in App.
- **WebSession class:** Good place to store session-scoped ViewModel instances that need to persist across page navigations.
- **Singleton caution:** Avoid singletons for user data in web apps — they work in desktop apps but cause data leaks between sessions in web apps.
- **Thread safety:** If ViewModels interact with background threads (timers, async calls), protect shared state with appropriate locking.

---

## 10. Quick Reference Checklist

### Starting a new feature:
- [ ] Define the **Model** class(es) — pure data + business rules, no UI
- [ ] Define the **ViewModel** class — UI state + commands, no View references
- [ ] Create the **View** (WebPage) — only reads/calls ViewModel, zero logic
- [ ] Wire up the notification mechanism (callback/event/pull)
- [ ] Write unit tests for Model and ViewModel before touching the View

### Code review checklist:
- [ ] Does the View contain any business logic? (should be NO)
- [ ] Does the ViewModel reference any WebPage controls? (should be NO)
- [ ] Does the Model know about the ViewModel or View? (should be NO)
- [ ] Is user-specific state stored in App instead of Session? (should be NO)
- [ ] Does each class have a single, clear responsibility?

---

## 11. References & Further Reading

- [Model–View–ViewModel — Wikipedia](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93viewmodel)
- [MVVM Architecture — Microsoft .NET MAUI Docs](https://learn.microsoft.com/en-us/dotnet/architecture/maui/mvvm)
- [MVVM Design Pattern — DZone Refcard](https://dzone.com/refcardz/mvvm-design-pattern-formula)
- [Design Patterns in Xojo — Xojo Blog](https://blog.xojo.com/tag/design-patterns/)
- [OOP Design Concepts — Xojo Documentation](https://documentation.xojo.com/getting_started/object-oriented_programming/oop_design_concepts.html)
- [MVC Discussion — Xojo Forum](https://forum.xojo.com/t/model-view-controller-mvc/10942)
- [MVVM in Web Applications — CodeGuru](https://www.codeguru.com/csharp/implementing-mvvm-pattern-in-web-applications-using-knockout/)
