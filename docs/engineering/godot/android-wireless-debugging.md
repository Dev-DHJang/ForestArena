# Android 무선 디버깅

Forest Arena는 Android 11 이상 기기의 **Wireless debugging** 기능을 사용한다. 페어링과 디버그 연결은 같은 Wi-Fi 네트워크에서 수행한다. 이 절차는 개발 컴퓨터에 Android SDK Platform-Tools (`adb`)가 설치되어 있다는 전제다.

## 최초 페어링

1. 기기에서 **개발자 옵션 > 무선 디버깅**을 켠다.
2. **페어링 코드로 기기 페어링**을 눌러 표시되는 `host:pairing-port`를 확인한다.
3. 개발 컴퓨터에서 아래 명령을 실행하고 기기에 표시된 일회성 코드를 입력한다.

   ```sh
   ./scripts/android-wireless-debug.sh pair <host:pairing-port>
   ```

페어링 코드와 Android 디버그 키는 문서·저장소·커밋에 넣지 않는다.

## 매 세션 연결과 확인

무선 디버깅 화면에 표시되는 `host:debug-port`로 연결한다. 페어링 포트와 디버그 포트는 다를 수 있으며, 포트는 세션마다 바뀔 수 있다.

```sh
./scripts/android-wireless-debug.sh connect <host:debug-port>
./scripts/android-wireless-debug.sh devices
./scripts/android-wireless-debug.sh verify <host:debug-port>
```

`verify`가 모델과 Android 버전을 표시하면 설치·실행 명령의 대상에 해당 serial을 명시할 수 있다.

```sh
adb -s <host:debug-port> install -r build/android/ForestArena-debug.apk
adb -s <host:debug-port> shell am start -W -n \
  com.forestarena.welllbeing/com.godot.game.GodotAppLauncher
```

## 문제 해결

- `unauthorized`이면 기기에서 RSA 디버깅 허용 대화상자를 승인한 뒤 다시 확인한다.
- `failed to connect`이면 두 기기가 같은 네트워크인지, 기기의 무선 디버깅 화면이 계속 열려 있는지, 새 디버그 포트가 표시되었는지 확인한다.
- 네트워크가 바뀌거나 재부팅 뒤 연결이 사라지면 `connect`부터 다시 수행한다. 페어링 자체가 사라진 경우에만 `pair`를 다시 실행한다.
- 회사·게스트 Wi-Fi가 기기간 통신을 차단하면 USB로 한 번 연결하거나, 기기와 개발 컴퓨터가 통신 가능한 네트워크를 사용한다.

기기 설정 화면, IP 주소, 포트, 페어링 코드는 환경별 값이므로 저장소에 기록하지 않는다.
