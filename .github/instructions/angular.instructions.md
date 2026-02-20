---
applyTo: "**/*.ts,**/*.html,**/*.scss,**/angular.json,**/*.component.*,**/*.service.*,**/*.guard.*,**/*.interceptor.*,**/*.pipe.*,**/*.directive.*"
---

# Angular Development Instructions

## Component Pattern (Standalone)

All new components MUST use the standalone component pattern:

    import { Component, ChangeDetectionStrategy, inject, signal, computed } from '@angular/core';
    import { CommonModule } from '@angular/common';
    import { RouterModule } from '@angular/router';

    @Component({
      selector: 'app-user-list',
      standalone: true,
      imports: [CommonModule, RouterModule],
      changeDetection: ChangeDetectionStrategy.OnPush,
      templateUrl: './user-list.component.html',
      styleUrl: './user-list.component.scss'
    })
    export class UserListComponent {
      private readonly userService = inject(UserService);

      protected readonly users = signal<User[]>([]);
      protected readonly isLoading = signal(false);
      protected readonly errorMessage = signal<string | null>(null);
      protected readonly userCount = computed(() => this.users().length);
      protected readonly hasUsers = computed(() => this.users().length > 0);

      constructor() {
        this.loadUsers();
      }

      private async loadUsers(): Promise<void> {
        this.isLoading.set(true);
        this.errorMessage.set(null);
        try {
          const result = await firstValueFrom(this.userService.getAll());
          this.users.set(result);
        } catch (error) {
          this.errorMessage.set('Failed to load users. Please try again.');
          console.error('Error loading users:', error);
        } finally {
          this.isLoading.set(false);
        }
      }
    }

---

## Template Pattern

Use Angular 17+ control flow syntax. NEVER use *ngIf or *ngFor:

    <!-- user-list.component.html -->
    <div class="user-list">
      <h2>Users ({{ userCount() }})</h2>

      @if (isLoading()) {
        <app-spinner />
      }

      @if (errorMessage(); as error) {
        <app-error-banner
          [message]="error"
          (retry)="loadUsers()" />
      }

      @if (hasUsers()) {
        <div class="user-grid">
          @for (user of users(); track user.id) {
            <app-user-card
              [user]="user"
              (selected)="onUserSelected($event)" />
          } @empty {
            <p class="no-results">No users found.</p>
          }
        </div>
      }
    </div>

---

## Service Pattern

    import { Injectable, inject } from '@angular/core';
    import { HttpClient, HttpParams } from '@angular/common/http';
    import { Observable } from 'rxjs';
    import { API_BASE_URL } from '@app/config/api.config';
    import { User, CreateUserRequest, UpdateUserRequest, PagedResult } from '@app/models/user.model';

    @Injectable({ providedIn: 'root' })
    export class UserService {
      private readonly http = inject(HttpClient);
      private readonly baseUrl = inject(API_BASE_URL);

      getAll(page: number = 1, pageSize: number = 20): Observable<PagedResult<User>> {
        const params = new HttpParams()
          .set('page', page.toString())
          .set('pageSize', pageSize.toString());

        return this.http.get<PagedResult<User>>(
          `${this.baseUrl}/api/v1/users`,
          { params }
        );
      }

      getById(id: string): Observable<User> {
        return this.http.get<User>(`${this.baseUrl}/api/v1/users/${id}`);
      }

      create(request: CreateUserRequest): Observable<User> {
        return this.http.post<User>(`${this.baseUrl}/api/v1/users`, request);
      }

      update(id: string, request: UpdateUserRequest): Observable<User> {
        return this.http.put<User>(`${this.baseUrl}/api/v1/users/${id}`, request);
      }

      delete(id: string): Observable<void> {
        return this.http.delete<void>(`${this.baseUrl}/api/v1/users/${id}`);
      }
    }

---

## Model Pattern

    // user.model.ts
    export interface User {
      id: string;
      email: string;
      displayName: string;
      createdAt: string;
      updatedAt: string | null;
    }

    export interface CreateUserRequest {
      email: string;
      displayName: string;
    }

    export interface UpdateUserRequest {
      displayName: string;
    }

    export interface PagedResult<T> {
      items: T[];
      totalCount: number;
      page: number;
      pageSize: number;
      totalPages: number;
      hasNextPage: boolean;
      hasPreviousPage: boolean;
    }

---

## API Configuration Pattern

    // api.config.ts
    import { InjectionToken } from '@angular/core';
    import { environment } from '@environments/environment';

    export const API_BASE_URL = new InjectionToken<string>('API_BASE_URL', {
      providedIn: 'root',
      factory: () => environment.apiBaseUrl
    });

---

## MSAL Auth Interceptor Pattern

    // auth.interceptor.ts
    import { HttpInterceptorFn } from '@angular/common/http';
    import { inject } from '@angular/core';
    import { MsalService } from '@azure/msal-angular';
    import { from, switchMap } from 'rxjs';
    import { environment } from '@environments/environment';

    export const authInterceptor: HttpInterceptorFn = (req, next) => {
      const msalService = inject(MsalService);

      // Skip auth for non-API requests
      if (!req.url.startsWith(environment.apiBaseUrl)) {
        return next(req);
      }

      return from(
        msalService.acquireTokenSilent({
          scopes: environment.apiScopes
        })
      ).pipe(
        switchMap(result => {
          const authReq = req.clone({
            setHeaders: {
              Authorization: `Bearer ${result.accessToken}`
            }
          });
          return next(authReq);
        })
      );
    };

Register in app.config.ts:

    export const appConfig: ApplicationConfig = {
      providers: [
        provideRouter(routes),
        provideHttpClient(
          withInterceptors([authInterceptor])
        ),
        // MSAL providers...
      ]
    };

---

## Auth Guard Pattern

    // auth.guard.ts
    import { inject } from '@angular/core';
    import { CanActivateFn, Router } from '@angular/router';
    import { MsalService } from '@azure/msal-angular';

    export const authGuard: CanActivateFn = () => {
      const msalService = inject(MsalService);
      const router = inject(Router);

      const accounts = msalService.instance.getAllAccounts();

      if (accounts.length > 0) {
        return true;
      }

      router.navigate(['/login']);
      return false;
    };

---

## Routing Pattern

    // app.routes.ts
    import { Routes } from '@angular/router';
    import { authGuard } from '@app/guards/auth.guard';

    export const routes: Routes = [
      {
        path: '',
        redirectTo: 'users',
        pathMatch: 'full'
      },
      {
        path: 'users',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./features/users/user-list/user-list.component')
            .then(m => m.UserListComponent)
      },
      {
        path: 'users/new',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./features/users/user-form/user-form.component')
            .then(m => m.UserFormComponent)
      },
      {
        path: 'users/:id',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./features/users/user-detail/user-detail.component')
            .then(m => m.UserDetailComponent)
      },
      {
        path: 'users/:id/edit',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./features/users/user-form/user-form.component')
            .then(m => m.UserFormComponent)
      },
      {
        path: '**',
        loadComponent: () =>
          import('./shared/components/not-found/not-found.component')
            .then(m => m.NotFoundComponent)
      }
    ];

---

## Reactive Forms Pattern

    import { Component, inject, signal } from '@angular/core';
    import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
    import { Router, ActivatedRoute } from '@angular/router';

    @Component({
      selector: 'app-user-form',
      standalone: true,
      imports: [ReactiveFormsModule, CommonModule],
      changeDetection: ChangeDetectionStrategy.OnPush,
      templateUrl: './user-form.component.html'
    })
    export class UserFormComponent {
      private readonly fb = inject(FormBuilder);
      private readonly userService = inject(UserService);
      private readonly router = inject(Router);
      private readonly route = inject(ActivatedRoute);

      protected readonly isSubmitting = signal(false);
      protected readonly errorMessage = signal<string | null>(null);
      protected readonly isEditMode = signal(false);

      protected readonly form = this.fb.nonNullable.group({
        email: ['', [Validators.required, Validators.email, Validators.maxLength(256)]],
        displayName: ['', [Validators.required, Validators.maxLength(100)]]
      });

      constructor() {
        const id = this.route.snapshot.paramMap.get('id');
        if (id) {
          this.isEditMode.set(true);
          this.loadUser(id);
        }
      }

      private async loadUser(id: string): Promise<void> {
        try {
          const user = await firstValueFrom(this.userService.getById(id));
          this.form.patchValue({
            email: user.email,
            displayName: user.displayName
          });
          // Disable email in edit mode
          this.form.controls.email.disable();
        } catch {
          this.errorMessage.set('Failed to load user.');
        }
      }

      protected async onSubmit(): Promise<void> {
        if (this.form.invalid) {
          this.form.markAllAsTouched();
          return;
        }

        this.isSubmitting.set(true);
        this.errorMessage.set(null);

        try {
          const formValue = this.form.getRawValue();

          if (this.isEditMode()) {
            const id = this.route.snapshot.paramMap.get('id')!;
            await firstValueFrom(this.userService.update(id, {
              displayName: formValue.displayName
            }));
          } else {
            await firstValueFrom(this.userService.create(formValue));
          }

          this.router.navigate(['/users']);
        } catch {
          this.errorMessage.set('Failed to save user. Please try again.');
        } finally {
          this.isSubmitting.set(false);
        }
      }
    }

Form template:

    <form [formGroup]="form" (ngSubmit)="onSubmit()">
      @if (errorMessage(); as error) {
        <app-error-banner [message]="error" />
      }

      <div class="form-field">
        <label for="email">Email</label>
        <input id="email" formControlName="email" type="email" />
        @if (form.controls.email.errors?.['required'] && form.controls.email.touched) {
          <span class="error">Email is required.</span>
        }
        @if (form.controls.email.errors?.['email'] && form.controls.email.touched) {
          <span class="error">Please enter a valid email.</span>
        }
      </div>

      <div class="form-field">
        <label for="displayName">Display Name</label>
        <input id="displayName" formControlName="displayName" type="text" />
        @if (form.controls.displayName.errors?.['required'] && form.controls.displayName.touched) {
          <span class="error">Display name is required.</span>
        }
      </div>

      <button type="submit" [disabled]="isSubmitting()">
        @if (isSubmitting()) {
          Saving...
        } @else {
          {{ isEditMode() ? 'Update' : 'Create' }} User
        }
      </button>
    </form>

---

## File and Folder Structure

Follow Angular CLI conventions:

    src/app/
    ├── app.component.ts
    ├── app.config.ts
    ├── app.routes.ts
    ├── config/
    │   ├── api.config.ts
    │   └── environment.ts
    ├── features/
    │   └── users/
    │       ├── user-list/
    │       │   ├── user-list.component.ts
    │       │   ├── user-list.component.html
    │       │   ├── user-list.component.scss
    │       │   └── user-list.component.spec.ts
    │       ├── user-detail/
    │       │   ├── user-detail.component.ts
    │       │   ├── user-detail.component.html
    │       │   ├── user-detail.component.scss
    │       │   └── user-detail.component.spec.ts
    │       ├── user-form/
    │       │   ├── user-form.component.ts
    │       │   ├── user-form.component.html
    │       │   ├── user-form.component.scss
    │       │   └── user-form.component.spec.ts
    │       └── user-card/
    │           ├── user-card.component.ts
    │           ├── user-card.component.html
    │           ├── user-card.component.scss
    │           └── user-card.component.spec.ts
    ├── guards/
    │   └── auth.guard.ts
    ├── interceptors/
    │   └── auth.interceptor.ts
    ├── models/
    │   └── user.model.ts
    ├── services/
    │   └── user.service.ts
    └── shared/
        └── components/
            ├── spinner/
            ├── error-banner/
            └── not-found/

---

## Rules Summary

1. ALWAYS use **standalone components** — never create NgModules
2. ALWAYS use **signals** for component state (signal, computed)
3. ALWAYS use `inject()` function — never constructor injection
4. ALWAYS use `ChangeDetectionStrategy.OnPush`
5. ALWAYS use `@for`, `@if`, `@switch` template syntax — never `*ngIf`, `*ngFor`
6. ALWAYS use `track` in `@for` loops with a unique identifier
7. ALWAYS lazy-load feature routes with `loadComponent`
8. ALWAYS use `canActivate` guards on protected routes
9. ALWAYS use **strict TypeScript** — no `any` types
10. ALWAYS use `FormBuilder.nonNullable.group()` for reactive forms
11. ALWAYS use `protected` access modifier for template-bound members
12. ALWAYS handle loading states and error states in components
13. ALWAYS use functional interceptors (HttpInterceptorFn) not class-based
14. ALWAYS use functional guards (CanActivateFn) not class-based
15. ALWAYS use `firstValueFrom` when converting Observable to Promise in async methods
16. NEVER import `BrowserModule` in standalone components — use `CommonModule`
17. NEVER use `subscribe` without proper cleanup — prefer signals or async pipe patterns
18. NEVER put business logic in components — use services
