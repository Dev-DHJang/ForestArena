import { ref } from 'vue';
export type Account={id:string;login_id:string;display_name:string;email:string|null;role:'SUPER_ADMIN'|'OPERATOR'|'VIEWER';active:boolean;must_change_password:boolean};
export const currentUser=ref<Account|null>(null);
export class ApiError extends Error { constructor(message:string,readonly status:number){super(message);} }
const messages:Record<string,string>={invalid_profile:'프로필 값이 올바르지 않습니다. 보유 목록과 선택 항목을 확인하세요.',invalid_nickname:'닉네임은 공백을 제외한 1~12자로 입력하세요.',invalid_request:'요청 값이 올바르지 않습니다. 변경 이유와 입력값을 확인하세요.',revision_conflict:'다른 변경이 저장되었습니다. 최신 데이터를 확인하세요.',request_id_conflict:'이 요청 ID로 다른 변경이 처리되었습니다. 최신 데이터를 확인하세요.',first_granted_immutable:'첫 지급 상태는 변경할 수 없습니다.',not_found:'항목을 찾을 수 없습니다.',invalid_page:'검색어나 페이지 값이 올바르지 않습니다.',revision_limit:'변경 번호 한도에 도달했습니다.'};
let csrf:{token:string;headerName:string}|null=null;
export async function request<T=any>(path:string,method='GET',body?:unknown):Promise<T>{
  const headers:Record<string,string>={'Accept':'application/json'};
  if(method!=='GET'){
    if(!csrf){const r=await fetch('/admin/api/v1/auth/csrf',{credentials:'same-origin',cache:'no-store'});if(!r.ok)throw new ApiError('보안 토큰을 가져올 수 없습니다.',r.status);csrf=await r.json();}
    headers[csrf!.headerName]=csrf!.token; headers['Content-Type']='application/json';
  }
  const response=await fetch('/admin/api/v1'+path,{method,headers,credentials:'same-origin',cache:'no-store',body:body===undefined?undefined:JSON.stringify(body)});
  const data=response.status===204?null:await response.json().catch(()=>null);
  if(!response.ok){if(response.status===403)csrf=null;if(response.status===401)currentUser.value=null;throw new ApiError(messages[data?.error]||data?.error||({403:'권한이 없거나 보안 토큰이 만료되었습니다.',409:'다른 변경이 있습니다. 최신 데이터를 확인하세요.',429:'시도가 너무 많습니다. 잠시 후 다시 시도하세요.'}[response.status])||'요청을 처리하지 못했습니다.',response.status);}
  return data;
}
export function resetCsrf(){csrf=null;}
export type Profile={schema_version:3;first_granted:boolean;nickname:string;characters:string[];accessories:string[];selected_character:string;selected_accessory:string;opponent_character:string;accessibility:{text_scale:number;reduce_visual_effects:boolean;haptics_enabled:boolean};minimap:{transparency:number;marker_style:string;show_names:boolean}};
export const roleNames={SUPER_ADMIN:'최고관리자',OPERATOR:'운영자',VIEWER:'조회자'};
export function pretty(value:unknown){return JSON.stringify(value,null,2);}
