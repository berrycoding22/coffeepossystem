export const roles = ["super_admin", "manager", "cashier", "barista"] as const;
export type UserRole = (typeof roles)[number];
export const roleLabels: Record<UserRole, string> = { super_admin: "Super Admin", manager: "Manager", cashier: "Cashier", barista: "Barista" };
