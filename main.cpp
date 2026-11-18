// main.cpp
// Простая игра‑демонстрация: двигающийся квадрат в безрамочном fullscreen‑окне.
// Скомпилировать, например:
//   cl /O2 /EHsc /Fe:Game.exe main.cpp          // MSVC
//   g++ -O2 -static -static-libgcc -static-libstdc++ -mwindows -o Game.exe main.cpp   // MinGW

#include <windows.h>

// ------------------------------------------------------------
// Параметры «игры»
constexpr int   SQUARE_SIZE = 50;          // размер квадрата (px)
constexpr int   SPEED_X     = 4;           // скорость по X (px/тик)
constexpr int   SPEED_Y     = 3;           // скорость по Y (px/тик)
constexpr UINT  TIMER_ID    = 1;           // ID таймера
constexpr UINT  TIMER_MS    = 16;          // интервал таймера (~60 FPS)
// ------------------------------------------------------------

struct GameState {
    int   x, y;        // текущая позиция левого‑верхнего угла квадрата
    int   vx, vy;      // текущая скорость
    int   screenW, screenH;
} gState = {0};

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
    case WM_CREATE:
    {
        // Получаем размеры экрана
        RECT rc;
        GetClientRect(hwnd, &rc);
        gState.screenW = rc.right;
        gState.screenH = rc.bottom;

        // Начальная позиция в центре
        gState.x = (gState.screenW  - SQUARE_SIZE) / 2;
        gState.y = (gState.screenH  - SQUARE_SIZE) / 2;
        gState.vx = SPEED_X;
        gState.vy = SPEED_Y;

        // Запускаем периодический таймер
        SetTimer(hwnd, TIMER_ID, TIMER_MS, nullptr);
        return 0;
    }

    case WM_TIMER:
        if (wParam == TIMER_ID)
        {
            // Обновляем положение
            gState.x += gState.vx;
            gState.y += gState.vy;

            // Отскок от границ окна
            if (gState.x < 0 || gState.x + SQUARE_SIZE > gState.screenW)  gState.vx = -gState.vx;
            if (gState.y < 0 || gState.y + SQUARE_SIZE > gState.screenH)  gState.vy = -gState.vy;

            // Перерисовываем
            InvalidateRect(hwnd, nullptr, FALSE);
        }
        return 0;

    case WM_PAINT:
    {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);

        // Заливаем фон чёрным
        HBRUSH hBack = CreateSolidBrush(RGB(0, 0, 0));
        FillRect(hdc, &ps.rcPaint, hBack);
        DeleteObject(hBack);

        // Рисуем квадрат (ярко‑зелёный)
        HBRUSH hSquare = CreateSolidBrush(RGB(0, 255, 0));
        RECT r = { gState.x, gState.y, gState.x + SQUARE_SIZE, gState.y + SQUARE_SIZE };
        FillRect(hdc, &r, hSquare);
        DeleteObject(hSquare);

        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_KEYDOWN:
        // ESC — выход
        if (wParam == VK_ESCAPE)
            PostMessage(hwnd, WM_CLOSE, 0, 0);
        return 0;

    case WM_DESTROY:
        KillTimer(hwnd, TIMER_ID);
        PostQuitMessage(0);
        return 0;
    }

    return DefWindowProc(hwnd, msg, wParam, lParam);
}

// ------------------------------------------------------------
// Точка входа
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE, LPSTR, int)
{
    const wchar_t CLASS_NAME[] = L"BorderlessGameWindow";

    WNDCLASS wc = {};
    wc.lpfnWndProc   = WndProc;
    wc.hInstance     = hInstance;
    wc.lpszClassName = CLASS_NAME;
    wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
    RegisterClass(&wc);

    // Получаем размер экрана
    int screenW = GetSystemMetrics(SM_CXSCREEN);
    int screenH = GetSystemMetrics(SM_CYSCREEN);

    // Создаём безрамочное окно, покрывающее весь экран
    HWND hwnd = CreateWindowEx(
        WS_EX_TOPMOST,           // всегда поверх других окон
        CLASS_NAME,
        L"Desktop Game",         // заголовок (не виден)
        WS_POPUP,                // без рамки, без заголовка
        0, 0, screenW, screenH,
        nullptr, nullptr, hInstance, nullptr);

    if (!hwnd) return 0;

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);

    // Основной цикл сообщений
    MSG msg = {};
    while (GetMessage(&msg, nullptr, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    return (int)msg.wParam;
}
