#![deny(unsafe_op_in_unsafe_fn)]
use std::slice;
#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct ArxTier2Result { pub code: i32, pub flags: u32 }
const URL:u32=1<<0; const CONFUSABLE:u32=1<<1; const OBFUSCATED:u32=1<<2; const SHELL_META:u32=1<<3; const ESCAPED:u32=1<<4;
#[inline] fn lower_ascii(b:u8)->u8{if b'A'<=b&&b<=b'Z'{b+32}else{b}}
#[inline] fn contains_ci(h:&[u8],n:&[u8])->bool{if n.is_empty()||n.len()>h.len(){return false} h.windows(n.len()).any(|w|w.iter().zip(n).all(|(a,b)|lower_ascii(*a)==lower_ascii(*b)))}
#[inline] fn analyze(input:&[u8])->ArxTier2Result{let mut flags=0;if contains_ci(input,b"http://")||contains_ci(input,b"https://")||contains_ci(input,b"ssh://"){flags|=URL}if flags&URL!=0&&input.iter().any(|b|*b>=0x80){flags|=CONFUSABLE}let meta=input.iter().filter(|b|matches!(**b,b'|'|b';'|b'&'|b'`'|b'$'|b'<'|b'>')).count();if meta>=3{flags|=SHELL_META}let alpha=input.iter().filter(|b|b.is_ascii_alphanumeric()||**b==b'+'||**b==b'/').count();if alpha>=32&&alpha*100/input.len().max(1)>70&&input.iter().any(|b|*b==b'='){flags|=OBFUSCATED}if input.windows(2).any(|w|w==b"\\x")||input.windows(2).any(|w|w==b"\\u"){flags|=ESCAPED}let code=if flags&(CONFUSABLE|OBFUSCATED|SHELL_META|ESCAPED)!=0{2}else{0};ArxTier2Result{code,flags}}
#[no_mangle] pub extern "C" fn arxguard_tier2_scan(ptr:*const u8,len:usize,out:*mut ArxTier2Result)->i32{if out.is_null(){return -1}let result=if ptr.is_null()||len==0{ArxTier2Result{code:0,flags:0}}else{let bytes=unsafe{slice::from_raw_parts(ptr,len)};analyze(bytes)};let code=result.code;unsafe{*out=result};code}
#[cfg(test)]mod tests{use super::*;#[test]fn clean(){assert_eq!(analyze(b"ls -la").code,0)}#[test]fn unicode_url_escalates(){assert_ne!(analyze("https://іnstall.dev".as_bytes()).flags&CONFUSABLE,0)}#[test]fn shell_density_escalates(){assert_ne!(analyze(b"a|b;c&d").flags&SHELL_META,0)}#[test]fn escaped_payload_escalates(){assert_ne!(analyze(br#"echo \\x72\\x6d"#).flags&ESCAPED,0)}}
