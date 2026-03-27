// hello OS v2.0 — Device Registry (Sesame Multi-Device)
// Manages per-user device registration, listing, and unlinking.
// Each user can have up to 5 linked devices with independent crypto identities.

import { supabase } from '../supabase';

export interface DeviceInfo {
  deviceId: number;
  platform: string;
  isPrimary: boolean;
  lastActiveAt?: string;
}

export async function registerDevice(device: {
  deviceId: number;
  deviceName: string;
  platform: string;
  isPrimary?: boolean;
}): Promise<void> {
  const { error } = await supabase.rpc('register_device', {
    p_device_id: device.deviceId,
    p_device_name: device.deviceName,
    p_platform: device.platform,
    p_is_primary: device.isPrimary ?? false,
  });
  if (error) throw new Error(`register_device failed: ${error.message}`);
}

export async function getUserDevices(userId: string): Promise<DeviceInfo[]> {
  const { data, error } = await supabase.rpc('get_user_devices', { p_user_id: userId });
  if (error) throw new Error(`get_user_devices failed: ${error.message}`);
  return (data ?? []).map((d: any) => ({
    deviceId: d.device_id,
    platform: d.platform,
    isPrimary: d.is_primary,
  }));
}

export async function unlinkDevice(deviceId: number): Promise<void> {
  const { error } = await supabase.rpc('unlink_device', { p_device_id: deviceId });
  if (error) throw new Error(`unlink_device failed: ${error.message}`);
}
