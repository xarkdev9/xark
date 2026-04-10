import pg from "pg";
const { Pool } = pg;
import type { PersistencePort } from "../ports/persistence.js";
import { VersionConflictError } from "../ports/persistence.js";
import type {
  BookableItem,
  DecisionSpace,
  ItemId,
  GroupId,
  Task,
  TaskId,
} from "../models/types.js";

/**
 * PostgreSQL Persistence Adapter
 * 
 * Production-ready database adapter that supports optimistic concurrency via version checks.
 * Expects the existence of three tables: algo_items, algo_tasks, and algo_spaces.
 * Schema: (id VARCHAR PRIMARY KEY, group_id VARCHAR, version INT, data JSONB)
 */
export class PostgresPersistenceAdapter implements PersistencePort {
  private pool: pg.Pool;

  constructor(connectionString: string) {
    this.pool = new Pool({ connectionString });
  }

  // --- Items ---
  async saveItem(item: BookableItem): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      
      const { rows } = await client.query(
        "SELECT version FROM algo_items WHERE id = $1 FOR UPDATE",
        [item.id]
      );
      
      const existingVersion = rows[0]?.version as number | undefined;
      
      if (existingVersion !== undefined && existingVersion >= item.version) {
        throw new VersionConflictError(item.id, item.version, existingVersion);
      }
      
      await client.query(
        `INSERT INTO algo_items (id, group_id, version, data) 
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (id) DO UPDATE SET 
         group_id = EXCLUDED.group_id,
         version = EXCLUDED.version,
         data = EXCLUDED.data`,
        [item.id, item.groupId, item.version, JSON.stringify(item)]
      );
      
      await client.query("COMMIT");
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }

  async getItem(itemId: ItemId): Promise<BookableItem | undefined> {
    const { rows } = await this.pool.query(
      "SELECT data FROM algo_items WHERE id = $1", 
      [itemId]
    );
    return rows[0]?.data as BookableItem | undefined;
  }

  async getItemsBySpace(groupId: GroupId): Promise<BookableItem[]> {
    const { rows } = await this.pool.query(
      "SELECT data FROM algo_items WHERE group_id = $1", 
      [groupId]
    );
    return rows.map(r => r.data as BookableItem);
  }

  async deleteItem(itemId: ItemId): Promise<void> {
    await this.pool.query("DELETE FROM algo_items WHERE id = $1", [itemId]);
  }

  // --- Tasks ---
  async saveTask(task: Task): Promise<void> {
    await this.pool.query(
      `INSERT INTO algo_tasks (id, group_id, data) 
       VALUES ($1, $2, $3)
       ON CONFLICT (id) DO UPDATE SET 
       group_id = EXCLUDED.group_id,
       data = EXCLUDED.data`,
      [task.id, task.groupId, JSON.stringify(task)]
    );
  }

  async getTask(taskId: TaskId): Promise<Task | undefined> {
    const { rows } = await this.pool.query(
      "SELECT data FROM algo_tasks WHERE id = $1", 
      [taskId]
    );
    return rows[0]?.data as Task | undefined;
  }

  async getTasksBySpace(groupId: GroupId): Promise<Task[]> {
    const { rows } = await this.pool.query(
      "SELECT data FROM algo_tasks WHERE group_id = $1", 
      [groupId]
    );
    return rows.map(r => r.data as Task);
  }

  async deleteTask(taskId: TaskId): Promise<void> {
    await this.pool.query("DELETE FROM algo_tasks WHERE id = $1", [taskId]);
  }

  // --- Spaces ---
  async saveSpace(space: DecisionSpace): Promise<void> {
    await this.pool.query(
      `INSERT INTO algo_spaces (id, group_id, data) 
       VALUES ($1, $1, $2)
       ON CONFLICT (id) DO UPDATE SET 
       data = EXCLUDED.data`,
      [space.id, JSON.stringify(space)]
    );
  }

  async getSpace(groupId: GroupId): Promise<DecisionSpace | undefined> {
    const { rows } = await this.pool.query(
      "SELECT data FROM algo_spaces WHERE id = $1", 
      [groupId]
    );
    return rows[0]?.data as DecisionSpace | undefined;
  }

  async getAllSpaces(): Promise<DecisionSpace[]> {
    const { rows } = await this.pool.query("SELECT data FROM algo_spaces");
    return rows.map(r => r.data as DecisionSpace);
  }

  async deleteSpace(groupId: GroupId): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("DELETE FROM algo_items WHERE group_id = $1", [groupId]);
      await client.query("DELETE FROM algo_tasks WHERE group_id = $1", [groupId]);
      await client.query("DELETE FROM algo_spaces WHERE id = $1", [groupId]);
      await client.query("COMMIT");
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }
}
