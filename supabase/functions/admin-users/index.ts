// Supabase Edge Function: privileged account creation and role assignment.
// Configure JWT verification, and also validate the user token here.
import { createClient } from 'npm:@supabase/supabase-js@2';
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json'};
const respond=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:cors});
const roles=['admin','leader','member','hr_viewer'];
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response(null,{headers:cors});
 if(req.method!=='POST')return respond({error:'Method not allowed'},405);
 try{
  const url=Deno.env.get('SUPABASE_URL'),anon=Deno.env.get('SUPABASE_ANON_KEY'),secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if(!url||!anon||!secret)return respond({error:'Missing server configuration'},500);
  const bearer=req.headers.get('authorization')||'';
  if(!bearer.startsWith('Bearer '))return respond({error:'Authentication required'},401);
  const userClient=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:identity,error:authErr}=await userClient.auth.getUser(bearer.slice(7));
  if(authErr||!identity.user)return respond({error:'Invalid session'},401);
  const admin=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:adminRow,error:adminErr}=await admin.from('admins').select('user_id').eq('user_id',identity.user.id).maybeSingle();
  if(adminErr||!adminRow)return respond({error:'Administrator privileges required'},403);
  const body=await req.json();
  if(body.action==='list'){
   const users=[];
   for(let page=1;page<=100;page++){
    const {data,error}=await admin.auth.admin.listUsers({page,perPage:100});if(error)throw error;
    users.push(...data.users);if(data.users.length<100)break;
   }
   const [{data:links,error:le},{data:roleRows,error:re},{data:adminRows,error:ae}]=await Promise.all([
    admin.from('employee_login_links').select('employee_name,user_id'),
    admin.from('user_team_roles').select('user_id,team_id,role'),
    admin.from('admins').select('user_id')
   ]);
   if(le||re||ae)throw le||re||ae;
   const adminIds=new Set((adminRows||[]).map(a=>a.user_id));
   return respond({users:users.map(u=>{const link=links?.find(l=>l.user_id===u.id);const role=roleRows?.find(r=>r.user_id===u.id);return {id:u.id,email:u.email,employee:link?.employee_name||null,role:adminIds.has(u.id)?'admin':role?.role||'member',team_id:role?.team_id||null,active:!(u.banned_until && new Date(u.banned_until).getTime()>Date.now())};})});
  }
  if(body.action==='reset-password'){
   if(typeof body.userId!=='string'||typeof body.password!=='string'||body.password.length<12||body.password.length>128)return respond({error:'Valid user ID and 12–128 character password required'},400);
   const {data:target,error:targetError}=await admin.auth.admin.getUserById(body.userId);
   if(targetError||!target.user)return respond({error:'User not found'},404);
   const {error}=await admin.auth.admin.updateUserById(body.userId,{password:body.password});if(error)throw error;
   return respond({success:true});
  }
  if(body.action==='update-user'){
   if(typeof body.userId!=='string')return respond({error:'Missing user ID'},400);
   const {data:target,error:targetError}=await admin.auth.admin.getUserById(body.userId);
   if(targetError||!target.user)return respond({error:'User not found'},404);
   const email=String(body.email||'').trim().toLowerCase();
   if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||email.length>254)return respond({error:'Valid email required'},400);
   if(typeof body.active!=='boolean')return respond({error:'Active status required'},400);
   if(body.userId===identity.user.id&&!body.active)return respond({error:'You cannot deactivate your own account'},400);
   if(!body.active){
    const {data:adminTarget,error:adminTargetErr}=await admin.from('admins').select('user_id').eq('user_id',body.userId).maybeSingle();
    if(adminTargetErr)throw adminTargetErr;
    if(adminTarget){const {count,error:countErr}=await admin.from('admins').select('user_id',{count:'exact',head:true});if(countErr)throw countErr;if((count||0)<=1)return respond({error:'Cannot deactivate the only administrator'},400);}
   }
   const {error}=await admin.auth.admin.updateUserById(body.userId,{email,email_confirm:true,ban_duration:body.active?'none':'876000h'});
   if(error)throw error;
   return respond({success:true});
  }
  if(body.action==='save-team'){
   const name=String(body.name||'').trim(),description=String(body.description||'').trim();
   if(!name||name.length>120||description.length>500)return respond({error:'Invalid team name or description'},400);
   const id=body.teamId==null?null:Number(body.teamId);
   if(id!==null&&(!Number.isInteger(id)||id<=0))return respond({error:'Invalid team ID'},400);
   const result=id===null?await admin.from('teams').insert({name,description}).select('id,name,description').single():await admin.from('teams').update({name,description}).eq('id',id).select('id,name,description').single();
   if(result.error)throw result.error;return respond({team:result.data});
  }
  if(body.action!=='create'&&body.action!=='set-role')return respond({error:'Unknown action'},400);
  const role=body.role;
  if(!roles.includes(role))return respond({error:'Invalid role'},400);
  const teamId=body.teamId==null?null:Number(body.teamId);
  if(['leader','member'].includes(role)&&(!Number.isInteger(teamId)||teamId<=0))return respond({error:'A team is required for team leader/user'},400);
  if(['admin','hr_viewer'].includes(role)&&teamId!==null)return respond({error:'This role must not have a team ID'},400);
  if(teamId!==null){const {data:team,error}=await admin.from('teams').select('id').eq('id',teamId).maybeSingle();if(error||!team)return respond({error:'Unknown team'},400);}
  async function setRole(userId:string){
   // Prevent removing own last administrative privilege via UI.
   if(userId===identity.user.id&&role!=='admin')throw Error('Cannot demote your own administrator account');
   const {error:delRole}=await admin.from('user_team_roles').delete().eq('user_id',userId);if(delRole)throw delRole;
   if(role!=='admin'){
    const {error:delAdmin}=await admin.from('admins').delete().eq('user_id',userId);if(delAdmin)throw delAdmin;
    const {error:ins}=await admin.from('user_team_roles').insert({user_id:userId,team_id:teamId,role});if(ins)throw ins;
   }else{
    const {error:ins}=await admin.from('admins').upsert({user_id:userId},{onConflict:'user_id'});if(ins)throw ins;
   }
  }
  if(body.action==='set-role'){
   if(typeof body.userId!=='string')return respond({error:'Missing user ID'},400);
   const {data:target,error}=await admin.auth.admin.getUserById(body.userId);if(error||!target.user)return respond({error:'Unknown user'},404);
   if(role==='leader'){
    const {data:link}=await admin.from('employee_login_links').select('employee_name').eq('user_id',body.userId).maybeSingle();
    if(!link)return respond({error:'Link this account to an employee before making them team leader'},400);
    const {data:emp}=await admin.from('employees').select('team_id').eq('name',link.employee_name).maybeSingle();
    if(emp?.team_id!==teamId)return respond({error:'Leader team must match linked employee team'},400);
   }
   await setRole(body.userId);return respond({success:true});
  }
  const email=String(body.email||'').trim().toLowerCase(),employee=String(body.employee||'').trim();
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||!employee)return respond({error:'Valid email and employee required'},400);
  const {data:emp,error:empErr}=await admin.from('employees').select('name,team_id').eq('name',employee).maybeSingle();
  if(empErr||!emp)return respond({error:'Employee not found'},400);
  if(['leader','member'].includes(role)&&emp.team_id!==teamId)return respond({error:'Account team must match employee team'},400);
  const {data:existing}=await admin.from('employee_login_links').select('user_id').eq('employee_name',employee).maybeSingle();
  if(existing)return respond({error:'Employee already linked to an account'},409);
  const method=body.method;
  if(method!=='invite'&&method!=='password')return respond({error:'Invalid creation method'},400);
  if(method==='password'&&(typeof body.password!=='string'||body.password.length<12||body.password.length>128))return respond({error:'Initial password must be 12–128 characters'},400);
  const created=method==='invite'
   ?await admin.auth.admin.inviteUserByEmail(email)
   :await admin.auth.admin.createUser({email,password:body.password,email_confirm:true});
  if(created.error||!created.data.user)return respond({error:created.error?.message||'Could not create account'},400);
  const id=created.data.user.id;
  try{
   const {error:linkErr}=await admin.from('employee_login_links').insert({employee_name:employee,user_id:id});if(linkErr)throw linkErr;
   await setRole(id);
  }catch(e){
   // Compensate failed provisioning: delete the newly created account and its link.
   await admin.auth.admin.deleteUser(id);
   throw e;
  }
  return respond({success:true,invited:method==='invite'});
 }catch(e){console.error('admin-users:',e);return respond({error:e instanceof Error?e.message:'Unexpected server error'},500);}
});
