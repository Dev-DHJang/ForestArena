# r03 코드 인계 — 실행 검증 대기

기존SceneTree._process본체를render_step(delta)로옮기고두LanMatchClient(defaultpriority0)뒤의Node relay(priority10000)가실제delta를그대로전달한다. 수신을보류하지않고client poll→sync→native draw→postdraw 순서를만든다. 기존draw/marker관련5함수본문은변경하지않았다.

처음양쪽클라이언트가SPAWNING종료/실제접지를관찰한뒤이동한다. 이동해제→서버tick+2→방향PRESS→두client방향과새tick확인→해제→tick+2→host재접근→해제→tick+2→강공격순서다. 모든대기실패는그단계에서시나리오를중단하고다음기술입력을보내지않는다. 같은tick으로PRESS/RELEASE가합쳐지지않도록정상입력을분리한fixture변경이다.

check-only-r01.log는exit0/ERROR0이며Python AST는정상이다. relay를포함한2828파일을새pin으로고정했다. actualdelta/marker검사/실제4그림존재기준은그대로다. 이전GPUprobe는공유3helper+자체wrapper만검사했으며r03relay나실제LANcallback의통과증거로확장하지않는다.

r02와실패capture파일해시를별도기록했고원본은그대로다. 실제GPU/소켓/포트실행은하지않았다. root가검토후새출력디렉터리에서실행해순서/방향/4그림/픽셀동일성을확인해야한다.
