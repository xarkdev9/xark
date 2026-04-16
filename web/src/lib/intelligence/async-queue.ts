/// Async AI worker queue. Heavy tasks (Apify scraping, long LLM calls)
/// return 202 Accepted instantly. Results delivered via Realtime.

export interface QueuedTask {
  taskId: string;
  type: 'apify_scrape' | 'gemini_search' | 'taste_analysis';
  payload: Record<string, any>;
  groupId: string;
  userId: string;
  status: 'pending' | 'processing' | 'complete' | 'failed';
  createdAt: number;
}

/**
 * Enqueue a heavy AI task for background processing.
 * Returns immediately with a taskId for status tracking.
 */
export async function enqueueAITask(task: Omit<QueuedTask, 'taskId' | 'status' | 'createdAt'>): Promise<string> {
  const taskId = crypto.randomUUID();

  // For now, use Supabase as the queue (future: Vercel Queues / Inngest)
  const { supabaseAdmin } = await import('../supabase-admin');
  await supabaseAdmin.from('ai_tasks').insert({
    id: taskId,
    type: task.type,
    payload: task.payload,
    group_id: task.groupId,
    user_id: task.userId,
    status: 'pending',
    created_at: new Date().toISOString(),
  });

  // TODO: Trigger background processing via Vercel Cron or webhook
  // For now, the /api/hello/webhook handles Apify callbacks

  return taskId;
}

/**
 * Check task status.
 */
export async function getTaskStatus(taskId: string): Promise<QueuedTask | null> {
  const { supabaseAdmin } = await import('../supabase-admin');
  const { data } = await supabaseAdmin
    .from('ai_tasks')
    .select('*')
    .eq('id', taskId)
    .single();
  return data as QueuedTask | null;
}
