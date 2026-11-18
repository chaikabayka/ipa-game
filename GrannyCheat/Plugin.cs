using System;
using System.Collections.Generic;
using BepInEx;
using BepInEx.Configuration;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using Il2CppInterop.Runtime;
using Il2CppInterop.Runtime.Injection;
using UnityEngine;

namespace GrannyCheat
{
    [BepInPlugin("abusegpt.granny.cheat", "Granny ESP + Aimbot", "1.3.0")]
    public class Plugin : BasePlugin
    {
        public override void Load()
        {
            Cfg.Esp       = Config.Bind("ESP",    "Enabled",   true, "Boxes");
            Cfg.EspKey    = Config.Bind("ESP",    "ToggleKey", KeyCode.F8);
            Cfg.EspLines  = Config.Bind("ESP",    "Snaplines", true);
            Cfg.EspState  = Config.Bind("ESP",    "ShowState", true);
            Cfg.ItemEsp   = Config.Bind("ESP",    "ItemEsp",   false, "Boxes on pickups");
            Cfg.Aim       = Config.Bind("Aim",    "Enabled",   true);
            Cfg.AimKey    = Config.Bind("Aim",    "Key",       KeyCode.LeftAlt);
            Cfg.Fov       = Config.Bind("Aim",    "FovPixels", 160f);
            Cfg.Smooth    = Config.Bind("Aim",    "Smooth",    14f);
            Cfg.AimHeight = Config.Bind("Aim",    "Height",    1.45f);
            Cfg.Silent    = Config.Bind("Silent", "Enabled",   true);
            Cfg.SilentKey = Config.Bind("Silent", "Key",       KeyCode.Mouse3);
            Cfg.FreezeKey = Config.Bind("Cheat",  "FreezeKey", KeyCode.F7);
            Cfg.MenuKey   = Config.Bind("Menu",   "Key",       KeyCode.F6);
            Cfg.Debug     = Config.Bind("Debug",  "LogScans",  false);

            State.Log = Log;

            ClassInjector.RegisterTypeInIl2Cpp<CheatBehaviour>();
            AddComponent<CheatBehaviour>();

            Log.LogInfo("granny cheat loaded");
        }
    }

    internal static class Cfg
    {
        public static ConfigEntry<bool> Esp;
        public static ConfigEntry<KeyCode> EspKey;
        public static ConfigEntry<bool> EspLines;
        public static ConfigEntry<bool> EspState;
        public static ConfigEntry<bool> ItemEsp;
        public static ConfigEntry<bool> Aim;
        public static ConfigEntry<KeyCode> AimKey;
        public static ConfigEntry<float> Fov;
        public static ConfigEntry<float> Smooth;
        public static ConfigEntry<float> AimHeight;
        public static ConfigEntry<bool> Silent;
        public static ConfigEntry<KeyCode> SilentKey;
        public static ConfigEntry<KeyCode> FreezeKey;
        public static ConfigEntry<KeyCode> MenuKey;
        public static ConfigEntry<bool> Debug;
    }

    internal class Mark
    {
        public Transform Body;
        public EnemyAIGranny AI;
    }

    internal class ItemMark
    {
        public GameObject Go;
        public Transform T;
        public string Name;
    }

    internal static class State
    {
        public static ManualLogSource Log;
        public static Camera Cam;
        public static FPSControllerNEW PC;
        public static shootGun Gun;
        public static PickUp Items;

        public static readonly List<Mark> Targets = new List<Mark>();
        public static readonly List<ItemMark> SceneItems = new List<ItemMark>();

        public static float NextScan;
        public static bool Frozen;
        public static bool GodMode;
        public static bool MenuOpen;
        public static int Tab;
        public static int LastCount = -1;
        public static int PageLib;
        public static int PageScene;

        public static float SpeedMul = 1f;
        public static float JumpMul = 1f;
        public static float GrannySlow = 1f;

        public static float OrigForward = -1f;
        public static float OrigBack = -1f;
        public static float OrigSide = -1f;
        public static float OrigJump = -1f;

        public static float OrigWalkSpeed = -1f;
        public static float OrigFollowSpeed = -1f;
    }

    public class CheatBehaviour : MonoBehaviour
    {
        public CheatBehaviour(IntPtr ptr) : base(ptr) { }

        private static readonly string[] ItemKeys =
        {
            "hammare", "safeKey", "exitKey", "hanglockKey", "padlockCode", "weaponKey",
            "playhouseKey", "carKey", "specialkey", "rustyPadlockKey", "spiderKey",
            "armborst", "oldShotgun", "ammo", "screwdriver", "planka", "battery",
            "kugg1", "kugg2", "brunnsvev", "wheelCrank", "gascan", "wrench",
            "sparkplug", "carbattery", "topplock", "melon", "teddy", "meat",
            "book", "pepperspray", "remote", "birdSeed", "freezeTrap",
            "chainCutter", "woodenStick", "deadRat", "christmasKula", "gunDel1",
            "gunDel2", "gunDel3"
        };

        private void Update()
        {
            if (Time.time >= State.NextScan)
            {
                State.NextScan = Time.time + 1.5f;
                Scan();
            }

            if (Input.GetKeyDown(Cfg.EspKey.Value))
                Cfg.Esp.Value = !Cfg.Esp.Value;

            if (Input.GetKeyDown(Cfg.MenuKey.Value))
            {
                State.MenuOpen = !State.MenuOpen;
                if (!State.MenuOpen)
                {
                    Cursor.lockState = CursorLockMode.Locked;
                    Cursor.visible = false;
                }
            }

            if (State.MenuOpen)
            {
                Cursor.lockState = CursorLockMode.None;
                Cursor.visible = true;
            }

            if (Input.GetKeyDown(Cfg.FreezeKey.Value))
            {
                State.Frozen = !State.Frozen;
                ApplyGranny();
            }

            ApplyPlayer();
        }

        private static Camera FindCamera()
        {
            var main = Camera.main;
            if (main != null) return main;

            Camera best = null;
            var all = UnityEngine.Object.FindObjectsOfType(Il2CppType.Of<Camera>());
            if (all == null) return null;

            foreach (var o in all)
            {
                if (o == null) continue;
                var cam = o.TryCast<Camera>();
                if (cam == null || !cam.isActiveAndEnabled) continue;
                if (best == null || cam.depth > best.depth) best = cam;
            }
            return best;
        }

        private static void Scan()
        {
            State.Cam = FindCamera();

            State.Targets.Clear();
            var live = UnityEngine.Object.FindObjectsOfType(Il2CppType.Of<EnemyAIGranny>());
            if (live != null)
            {
                foreach (var o in live)
                {
                    if (o == null) continue;
                    var ai = o.TryCast<EnemyAIGranny>();
                    if (ai == null) continue;
                    var body = ai.myTransform != null ? ai.myTransform : ai.transform;
                    if (body == null) continue;
                    State.Targets.Add(new Mark { Body = body, AI = ai });
                }
            }

            State.PC = null;
            var pcs = UnityEngine.Object.FindObjectsOfType(Il2CppType.Of<FPSControllerNEW>());
            if (pcs != null)
                foreach (var o in pcs)
                {
                    if (o == null) continue;
                    State.PC = o.TryCast<FPSControllerNEW>();
                    if (State.PC != null) break;
                }

            State.Gun = null;
            var guns = UnityEngine.Object.FindObjectsOfType(Il2CppType.Of<shootGun>());
            if (guns != null)
                foreach (var o in guns)
                {
                    if (o == null) continue;
                    State.Gun = o.TryCast<shootGun>();
                    if (State.Gun != null) break;
                }

            State.Items = null;
            var pus = UnityEngine.Object.FindObjectsOfType(Il2CppType.Of<PickUp>());
            if (pus != null)
                foreach (var o in pus)
                {
                    if (o == null) continue;
                    State.Items = o.TryCast<PickUp>();
                    if (State.Items != null) break;
                }

            State.SceneItems.Clear();
            var puns = UnityEngine.Object.FindObjectsOfType(Il2CppType.Of<PickUpNew>());
            if (puns != null)
            {
                foreach (var o in puns)
                {
                    if (o == null) continue;
                    var pu = o.TryCast<PickUpNew>();
                    if (pu == null) continue;
                    var t = pu.transform;
                    if (t == null) continue;
                    State.SceneItems.Add(new ItemMark { Go = pu.gameObject, T = t, Name = t.name });
                }
            }

            ApplyGranny();

            if (State.Targets.Count != State.LastCount)
            {
                State.LastCount = State.Targets.Count;

                string eye = "n/a";
                var first = State.Targets.Count > 0 ? State.Targets[0] : null;
                if (first != null && first.AI != null && first.AI.grannyEye != null && first.Body != null)
                    eye = Mathf.Abs(first.AI.grannyEye.position.y - first.Body.position.y).ToString("F2");

                State.Log?.LogInfo("targets=" + State.LastCount +
                                   " pc=" + (State.PC != null) +
                                   " gun=" + (State.Gun != null) +
                                   " pickup=" + (State.Items != null) +
                                   " sceneItems=" + State.SceneItems.Count +
                                   " eyeDist=" + eye);
            }
        }

        private static Transform PlayerTransform()
        {
            if (State.PC != null)
            {
                var t = State.PC.thisTransform;
                if (t != null) return t;
                return State.PC.transform;
            }
            return State.Cam != null ? State.Cam.transform : null;
        }

        private static void ApplyPlayer()
        {
            var pc = State.PC;
            if (pc == null) return;

            if (State.SpeedMul == 1f && State.JumpMul == 1f)
            {
                if (State.OrigForward > 0f)
                {
                    pc.forwardSpeed = State.OrigForward;
                    pc.backwardSpeed = State.OrigBack;
                    pc.sidestepSpeed = State.OrigSide;
                    pc.jumpSpeed = State.OrigJump;
                    State.OrigForward = -1f;
                    State.Log?.LogInfo("player speeds restored");
                }
                return;
            }

            if (State.OrigForward <= 0f)
            {
                if (pc.forwardSpeed <= 0.001f) return;
                State.OrigForward = pc.forwardSpeed;
                State.OrigBack = pc.backwardSpeed;
                State.OrigSide = pc.sidestepSpeed;
                State.OrigJump = pc.jumpSpeed;
            }

            pc.forwardSpeed = State.OrigForward * State.SpeedMul;
            pc.backwardSpeed = State.OrigBack * State.SpeedMul;
            pc.sidestepSpeed = State.OrigSide * State.SpeedMul;
            pc.jumpSpeed = State.OrigJump * State.JumpMul;
        }

        private static void ApplyGranny()
        {
            bool touchSpeed = Mathf.Abs(State.GrannySlow - 1f) > 0.001f;

            foreach (var m in State.Targets)
            {
                if (m.AI == null) continue;

                m.AI.freeze = State.Frozen;
                m.AI.dontHitPlayer = State.GodMode;

                if (!touchSpeed)
                {
                    if (State.OrigWalkSpeed > 0f)
                    {
                        m.AI.walkSpeed = State.OrigWalkSpeed;
                        m.AI.grannysFollowSpeed = State.OrigFollowSpeed;
                    }
                    continue;
                }

                if (State.OrigWalkSpeed <= 0f)
                {
                    if (m.AI.walkSpeed <= 0.001f) continue;
                    State.OrigWalkSpeed = m.AI.walkSpeed;
                    State.OrigFollowSpeed = m.AI.grannysFollowSpeed;
                }

                m.AI.walkSpeed = State.OrigWalkSpeed * State.GrannySlow;
                m.AI.grannysFollowSpeed = State.OrigFollowSpeed * State.GrannySlow;
            }

            if (!touchSpeed) State.OrigWalkSpeed = -1f;
        }

        private static bool TryScreenRect(Transform root, Camera cam, out Rect rect)
        {
            rect = new Rect(0f, 0f, 0f, 0f);
            if (root == null || cam == null) return false;

            var rends = root.GetComponentsInChildren(Il2CppType.Of<Renderer>(), true);
            if (rends == null) return false;

            float minX = float.MaxValue, maxX = float.MinValue;
            float minY = float.MaxValue, maxY = float.MinValue;
            bool any = false;

            foreach (var o in rends)
            {
                if (o == null) continue;
                var r = o.TryCast<Renderer>();
                if (r == null || !r.enabled) continue;

                Bounds b = r.bounds;
                float size = b.size.magnitude;
                if (size > 6f || size < 0.02f) continue;
                if (Vector3.Distance(b.center, root.position) > 3.5f) continue;

                Vector3 c = b.center;
                Vector3 e = b.extents;

                for (int i = 0; i < 8; i++)
                {
                    var p = new Vector3(
                        c.x + (((i & 1) == 0) ? -e.x : e.x),
                        c.y + (((i & 2) == 0) ? -e.y : e.y),
                        c.z + (((i & 4) == 0) ? -e.z : e.z));

                    var s = cam.WorldToScreenPoint(p);
                    if (s.z <= 0f) continue;

                    float sx = s.x;
                    float sy = Screen.height - s.y;
                    if (sx < minX) minX = sx;
                    if (sx > maxX) maxX = sx;
                    if (sy < minY) minY = sy;
                    if (sy > maxY) maxY = sy;
                    any = true;
                }
            }

            if (!any) return false;

            float w = maxX - minX;
            float h = maxY - minY;
            if (w < 2f || h < 2f) return false;
            if (w > Screen.width * 1.5f || h > Screen.height * 1.5f) return false;

            rect = new Rect(minX, minY, w, h);
            return true;
        }

        private static bool ProjectPoint(Camera cam, Vector3 p,
            ref float minX, ref float maxX, ref float minY, ref float maxY)
        {
            var s = cam.WorldToScreenPoint(p);
            if (s.z <= 0f) return false;

            float sx = s.x;
            float sy = Screen.height - s.y;
            if (sx < minX) minX = sx;
            if (sx > maxX) maxX = sx;
            if (sy < minY) minY = sy;
            if (sy > maxY) maxY = sy;
            return true;
        }

        // бокс по глазу и ступням — не зависит от масштаба модели и мусорных мешей
        private static bool TryBodyRect(Mark m, Camera cam, out Rect rect, out float worldHeight)
        {
            rect = new Rect(0f, 0f, 0f, 0f);
            worldHeight = 1.7f;
            if (m == null || m.Body == null || cam == null) return false;

            Vector3 feet = m.Body.position;
            float eyeDrop = 0f;

            if (m.AI != null && m.AI.grannyEye != null)
                eyeDrop = Mathf.Abs(m.AI.grannyEye.position.y - feet.y);

            if (eyeDrop > 0.05f)
                worldHeight = eyeDrop / 0.93f;

            float total = worldHeight * 1.0f;

            Vector3 right = cam.transform.right;
            float halfW = total * 0.24f;

            float minX = float.MaxValue, maxX = float.MinValue;
            float minY = float.MaxValue, maxY = float.MinValue;
            bool any = false;

            Vector3 a = feet - right * halfW;
            Vector3 b = feet + right * halfW;
            Vector3 c = feet + Vector3.up * total - right * halfW;
            Vector3 d = feet + Vector3.up * total + right * halfW;

            any |= ProjectPoint(cam, a, ref minX, ref maxX, ref minY, ref maxY);
            any |= ProjectPoint(cam, b, ref minX, ref maxX, ref minY, ref maxY);
            any |= ProjectPoint(cam, c, ref minX, ref maxX, ref minY, ref maxY);
            any |= ProjectPoint(cam, d, ref minX, ref maxX, ref minY, ref maxY);

            if (!any) return false;

            float w = maxX - minX;
            float h = maxY - minY;
            if (w < 2f || h < 2f) return false;
            if (w > Screen.width * 2f || h > Screen.height * 2f) return false;

            rect = new Rect(minX, minY, w, h);
            return true;
        }

        private void OnGUI()
        {
            if (State.MenuOpen) DrawMenu();

            if (!Cfg.Esp.Value || State.Cam == null) return;
            GUI.skin.label.fontSize = 12;

            foreach (var m in State.Targets)
            {
                if (m.Body == null) continue;
                if (!TryBodyRect(m, State.Cam, out var rect, out float worldHeight)) continue;

                float dist = Vector3.Distance(State.Cam.transform.position, m.Body.position)
                           * (1.7f / Mathf.Max(worldHeight, 0.2f));
                Color col = dist < 8f ? Color.red
                          : dist < 18f ? new Color(1f, 0.6f, 0.1f)
                          : Color.green;

                DrawBox(rect, col, 1.5f);

                if (Cfg.EspState.Value)
                {
                    GUI.color = col;
                    GUI.Label(new Rect(rect.x - 30f, rect.y - 32f, rect.width + 60f, 16f),
                        m.AI == null ? "granny"
                        : m.AI.huntPlayer ? "HUNT"
                        : m.AI.GrannySearching ? "SEARCH" : "IDLE");
                    GUI.Label(new Rect(rect.x - 30f, rect.y - 16f, rect.width + 60f, 16f),
                        dist.ToString("F0") + "m");
                }

                if (Cfg.EspLines.Value)
                {
                    GUI.color = new Color(col.r, col.g, col.b, 0.55f);
                    DrawLine(new Vector2(Screen.width * 0.5f, Screen.height),
                             new Vector2(rect.center.x, rect.yMax), 1.2f);
                }
            }

            if (Cfg.ItemEsp.Value)
            {
                foreach (var it in State.SceneItems)
                {
                    if (it.T == null) continue;
                    if (!TryScreenRect(it.T, State.Cam, out var rect)) continue;
                    if (rect.height > Screen.height * 0.5f) continue;

                    GUI.color = new Color(0.3f, 0.8f, 1f);
                    DrawBox(rect, GUI.color, 1f);
                    GUI.Label(new Rect(rect.x - 40f, rect.y - 16f, rect.width + 80f, 16f), it.Name);
                }
            }

            GUI.color = Color.white;
        }

        private static void DrawMenu()
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;

            GUI.color = Color.white;
            GUI.skin.label.fontSize = 13;

            var panel = new Rect(20f, 20f, 640f, 470f);
            GUI.Box(panel, "");
            GUI.Label(new Rect(32f, 28f, 500f, 20f), "GRANNY CHEAT  —  " + Cfg.MenuKey.Value + " to close");

            string[] tabs = { "PLAYER", "GRANNY", "ITEMS", "VISUAL" };
            for (int i = 0; i < tabs.Length; i++)
            {
                if (GUI.Button(new Rect(32f + i * 154f, 52f, 148f, 26f), tabs[i]))
                    State.Tab = i;
            }

            switch (State.Tab)
            {
                case 0: DrawPlayerTab(); break;
                case 1: DrawGrannyTab(); break;
                case 2: DrawItemsTab(); break;
                default: DrawVisualTab(); break;
            }
        }

        private static void DrawPlayerTab()
        {
            var t = PlayerTransform();
            float y = 92f;

            GUI.Label(new Rect(32f, y, 560f, 20f), t == null
                ? "player: not found"
                : "position  " + t.position.x.ToString("F1") + "  " + t.position.y.ToString("F1") + "  " + t.position.z.ToString("F1"));
            y += 30f;

            if (GUI.Button(new Rect(32f, y, 220f, 26f), "god mode (granny can't hit)"))
                State.GodMode = !State.GodMode;
            GUI.Label(new Rect(262f, y, 120f, 26f), State.GodMode ? "ON" : "off");
            y += 32f;

            GUI.Label(new Rect(32f, y, 200f, 26f), "speed  x" + State.SpeedMul.ToString("F1"));
            if (GUI.Button(new Rect(210f, y, 60f, 26f), "x1")) State.SpeedMul = 1f;
            if (GUI.Button(new Rect(276f, y, 60f, 26f), "x2")) State.SpeedMul = 2f;
            if (GUI.Button(new Rect(342f, y, 60f, 26f), "x3")) State.SpeedMul = 3f;
            if (GUI.Button(new Rect(408f, y, 60f, 26f), "x5")) State.SpeedMul = 5f;
            y += 32f;

            GUI.Label(new Rect(32f, y, 200f, 26f), "jump  x" + State.JumpMul.ToString("F1"));
            if (GUI.Button(new Rect(210f, y, 60f, 26f), "x1")) State.JumpMul = 1f;
            if (GUI.Button(new Rect(276f, y, 60f, 26f), "x2")) State.JumpMul = 2f;
            if (GUI.Button(new Rect(342f, y, 60f, 26f), "x3")) State.JumpMul = 3f;
            y += 40f;

            if (GUI.Button(new Rect(32f, y, 220f, 26f), "teleport to granny"))
            {
                var g = FirstGranny();
                var p = PlayerTransform();
                if (g != null && p != null) Teleport(p, g.position + g.forward * -1.5f);
            }

            y += 32f;
            GUI.Label(new Rect(32f, y, 560f, 20f), "uses CharacterController-safe teleport");
        }

        private static void DrawGrannyTab()
        {
            float y = 92f;

            if (GUI.Button(new Rect(32f, y, 220f, 26f), "freeze / unfreeze"))
                State.Frozen = !State.Frozen;
            GUI.Label(new Rect(262f, y, 120f, 26f), State.Frozen ? "FROZEN" : "active");
            y += 32f;

            GUI.Label(new Rect(32f, y, 200f, 26f), "speed  x" + State.GrannySlow.ToString("F1"));
            if (GUI.Button(new Rect(210f, y, 60f, 26f), "x0")) State.GrannySlow = 0f;
            if (GUI.Button(new Rect(276f, y, 60f, 26f), "0.5")) State.GrannySlow = 0.5f;
            if (GUI.Button(new Rect(342f, y, 60f, 26f), "x1")) State.GrannySlow = 1f;
            if (GUI.Button(new Rect(408f, y, 60f, 26f), "x2")) State.GrannySlow = 2f;
            y += 40f;

            if (GUI.Button(new Rect(32f, y, 220f, 26f), "teleport granny to me"))
            {
                var g = FirstGranny();
                var p = PlayerTransform();
                if (g != null && p != null) g.position = p.position + p.forward * 2f;
            }
            y += 32f;

            if (GUI.Button(new Rect(32f, y, 220f, 26f), "blind her"))
            {
                foreach (var m in State.Targets)
                    if (m.AI != null) m.AI.blindTimer = 999f;
            }
            y += 32f;

            if (GUI.Button(new Rect(32f, y, 220f, 26f), "kill / ragdoll"))
            {
                foreach (var m in State.Targets)
                    if (m.AI != null) m.AI.grannyHitByGun();
            }
            y += 32f;

            if (GUI.Button(new Rect(32f, y, 220f, 26f), "trigger escape (win)"))
            {
                foreach (var m in State.Targets)
                    if (m.AI != null) m.AI.PlayerEscaped = true;
            }
        }

        private static void DrawItemsTab()
        {
            const int perPage = 10;
            float y = 116f;

            GUI.Label(new Rect(32f, 92f, 280f, 20f), "LIBRARY");
            GUI.Label(new Rect(344f, 92f, 268f, 20f), "IN LEVEL (" + State.SceneItems.Count + ")");

            int libPages = Mathf.Max(1, (ItemKeys.Length + perPage - 1) / perPage);
            if (State.PageLib >= libPages) State.PageLib = libPages - 1;
            if (State.PageLib < 0) State.PageLib = 0;

            int start = State.PageLib * perPage;
            for (int i = 0; i < perPage; i++)
            {
                int idx = start + i;
                if (idx >= ItemKeys.Length) break;

                string key = ItemKeys[idx];
                var prop = State.Items != null ? typeof(PickUp).GetProperty(key) : null;
                var val = prop != null ? prop.GetValue(State.Items) as GameObject : null;
                bool ok = val != null;

                GUI.enabled = ok;
                if (GUI.Button(new Rect(32f, y + i * 28f, 264f, 26f), ok ? key : key + "  ·"))
                    SpawnItem(key);
                GUI.enabled = true;
            }

            int scenePages = Mathf.Max(1, (State.SceneItems.Count + perPage - 1) / perPage);
            if (State.PageScene >= scenePages) State.PageScene = scenePages - 1;
            if (State.PageScene < 0) State.PageScene = 0;

            int sstart = State.PageScene * perPage;
            for (int i = 0; i < perPage; i++)
            {
                int idx = sstart + i;
                if (idx >= State.SceneItems.Count) break;

                var it = State.SceneItems[idx];
                if (it.T == null) continue;
                if (GUI.Button(new Rect(344f, y + i * 28f, 264f, 26f), it.Name))
                    Duplicate(it);
            }

            float py = y + perPage * 28f + 4f;

            if (GUI.Button(new Rect(32f, py, 56f, 24f), "<")) State.PageLib--;
            GUI.Label(new Rect(92f, py + 2f, 140f, 22f), "page " + (State.PageLib + 1) + " / " + libPages);
            if (GUI.Button(new Rect(240f, py, 56f, 24f), ">")) State.PageLib++;

            if (GUI.Button(new Rect(344f, py, 56f, 24f), "<")) State.PageScene--;
            GUI.Label(new Rect(404f, py + 2f, 60f, 22f), (State.PageScene + 1) + " / " + scenePages);
            if (GUI.Button(new Rect(552f, py, 56f, 24f), ">")) State.PageScene++;

            py += 30f;
            if (GUI.Button(new Rect(32f, py, 264f, 26f), "all scene items -> me"))
            {
                var p = PlayerTransform();
                if (p != null) BringItems(p);
            }
            if (GUI.Button(new Rect(344f, py, 264f, 26f), "duplicate next to me"))
            {
                int idx = State.PageScene * perPage;
                if (idx < State.SceneItems.Count) Duplicate(State.SceneItems[idx]);
            }
        }

        private static void DrawVisualTab()
        {
            float y = 92f;

            if (GUI.Button(new Rect(32f, y, 220f, 26f), "esp"))
                Cfg.Esp.Value = !Cfg.Esp.Value;
            GUI.Label(new Rect(262f, y, 120f, 26f), Cfg.Esp.Value ? "ON" : "off");
            y += 32f;

            if (GUI.Button(new Rect(32f, y, 220f, 26f), "item esp"))
                Cfg.ItemEsp.Value = !Cfg.ItemEsp.Value;
            GUI.Label(new Rect(262f, y, 120f, 26f), Cfg.ItemEsp.Value ? "ON" : "off");
            y += 32f;

            if (GUI.Button(new Rect(32f, y, 220f, 26f), "snaplines"))
                Cfg.EspLines.Value = !Cfg.EspLines.Value;
            GUI.Label(new Rect(262f, y, 120f, 26f), Cfg.EspLines.Value ? "ON" : "off");
            y += 40f;

            GUI.Label(new Rect(32f, y, 200f, 26f), "time scale  x" + Time.timeScale.ToString("F1"));
            if (GUI.Button(new Rect(200f, y, 60f, 26f), "0.3")) Time.timeScale = 0.3f;
            if (GUI.Button(new Rect(266f, y, 60f, 26f), "x1")) Time.timeScale = 1f;
            if (GUI.Button(new Rect(332f, y, 60f, 26f), "x2")) Time.timeScale = 2f;
            if (GUI.Button(new Rect(398f, y, 60f, 26f), "x4")) Time.timeScale = 4f;
        }

        private static Transform FirstGranny()
        {
            foreach (var m in State.Targets)
                if (m.Body != null) return m.Body;
            return null;
        }

        private static void Teleport(Transform who, Vector3 dest)
        {
            var pc = State.PC;
            var cc = pc != null ? pc.character : null;
            if (cc != null) cc.enabled = false;
            who.position = dest;
            if (cc != null) cc.enabled = true;
        }

        private static float GameScale()
        {
            var pc = State.PC;
            if (pc != null && pc.character != null)
            {
                float h = pc.character.height;
                if (h > 0.5f) return h / 1.8f;
            }
            return 1f;
        }

        private static void DropInFront(GameObject go)
        {
            if (go == null || State.Cam == null) return;

            float s = GameScale();
            var camT = State.Cam.transform;

            go.SetActive(true);
            go.transform.position = camT.position
                + camT.forward * (2.6f * s)
                + Vector3.down * (0.6f * s);
            go.transform.rotation = camT.rotation;
        }

        private static void BringItems(Transform player)
        {
            float s = GameScale();
            int n = 0;

            foreach (var it in State.SceneItems)
            {
                if (it.T == null) continue;
                if (it.Go != null) it.Go.SetActive(true);

                float ang = n * 0.7f;
                it.T.position = player.position
                    + player.forward * (2.2f * s)
                    + new Vector3(Mathf.Cos(ang) * (0.7f * s), 0f, Mathf.Sin(ang) * (0.7f * s));
                n++;
            }
            State.Log?.LogInfo("brought " + n + " items");
        }

        private static void Duplicate(ItemMark it)
        {
            if (it.Go == null || State.Cam == null) return;
            var clone = UnityEngine.Object.Instantiate(it.Go);
            var go = clone != null ? clone.TryCast<GameObject>() : null;
            DropInFront(go);
            State.Log?.LogInfo("cloned " + it.Name);
        }

        private static void SpawnItem(string key)
        {
            if (State.Items == null || State.Cam == null) return;

            var prop = typeof(PickUp).GetProperty(key);
            var prefab = prop != null ? prop.GetValue(State.Items) as GameObject : null;
            if (prefab == null) return;

            var clone = UnityEngine.Object.Instantiate(prefab);
            var go = clone != null ? clone.TryCast<GameObject>() : null;
            if (go == null) return;

            DropInFront(go);
            State.Log?.LogInfo("spawned " + key);
        }

        private void LateUpdate()
        {
            if (State.Cam == null) return;
            if (Cfg.Silent.Value && Input.GetKey(Cfg.SilentKey.Value)) SilentAim();
            if (Cfg.Aim.Value && Input.GetKey(Cfg.AimKey.Value)) SnapAim();
        }

        private static Transform PickClosest()
        {
            float cx = Screen.width * 0.5f;
            float cy = Screen.height * 0.5f;
            float best = float.MaxValue;
            Transform pick = null;

            foreach (var m in State.Targets)
            {
                var body = m.Body;
                if (body == null) continue;

                Vector3 sp = State.Cam.WorldToScreenPoint(body.position + Vector3.up * Cfg.AimHeight.Value);
                if (sp.z <= 0f) continue;

                float d = Vector2.Distance(new Vector2(sp.x, sp.y), new Vector2(cx, cy));
                if (d < Cfg.Fov.Value && d < best) { best = d; pick = body; }
            }
            return pick;
        }

        private static void SnapAim()
        {
            var pick = PickClosest();
            if (pick == null) return;

            Vector3 aim = pick.position + Vector3.up * Cfg.AimHeight.Value;
            Quaternion rot = Quaternion.LookRotation(aim - State.Cam.transform.position);
            State.Cam.transform.rotation = Quaternion.Slerp(
                State.Cam.transform.rotation, rot, Time.deltaTime * Cfg.Smooth.Value);
        }

        private static void SilentAim()
        {
            if (State.Gun == null || State.Gun.SeeRay1 == null) return;
            var pick = PickClosest();
            if (pick == null) return;

            var rayT = State.Gun.SeeRay1.transform;
            if (rayT == null) return;

            Vector3 aim = pick.position + Vector3.up * Cfg.AimHeight.Value;
            rayT.rotation = Quaternion.LookRotation(aim - rayT.position);
        }

        private static void DrawBox(Rect r, Color c, float th)
        {
            var old = GUI.color;
            GUI.color = c;
            GUI.DrawTexture(new Rect(r.x, r.y, r.width, th), Texture2D.whiteTexture);
            GUI.DrawTexture(new Rect(r.x, r.yMax - th, r.width, th), Texture2D.whiteTexture);
            GUI.DrawTexture(new Rect(r.x, r.y, th, r.height), Texture2D.whiteTexture);
            GUI.DrawTexture(new Rect(r.xMax - th, r.y, th, r.height), Texture2D.whiteTexture);
            GUI.color = old;
        }

        private static void DrawLine(Vector2 a, Vector2 b, float th)
        {
            Vector2 d = b - a;
            float len = d.magnitude;
            if (len < 1f) return;

            float angle = Mathf.Atan2(d.y, d.x) * Mathf.Rad2Deg;
            Matrix4x4 m = GUI.matrix;
            GUIUtility.RotateAroundPivot(angle, a);
            GUI.DrawTexture(new Rect(a.x, a.y - th * 0.5f, len, th), Texture2D.whiteTexture);
            GUI.matrix = m;
        }
    }
}
