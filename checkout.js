// Secret KFS cart and checkout module
(() => {
  const db = window.supabase.createClient('https://ywhwqpijlevtoqvhodkf.supabase.co','sb_publishable_x2MuIwfoQKZ6R33K1Tl4_Q_8HZJIUSY');
  const $ = (s) => document.querySelector(s);
  let cart = {};
  try { cart = JSON.parse(localStorage.getItem('secret_cart') || '{}'); } catch (_) {}
  const money = n => Number(n || 0).toLocaleString('ar-EG');
  const save = () => { localStorage.setItem('secret_cart', JSON.stringify(cart)); const el=$('#cartCount'); if(el) el.textContent=Object.values(cart).reduce((n,x)=>n+x.quantity,0); };
  const show = id => { const el=$('#'+id); if(el) el.style.display='block'; };
  const hide = id => { const el=$('#'+id); if(el) el.style.display='none'; };
  function draw() {
    const rows=Object.entries(cart).filter(([,x])=>x.quantity>0);
    $('#cartItems').innerHTML=rows.length?rows.map(([id,x])=>'<p>'+x.name+' — '+money(x.price)+' ج.م <button data-minus="'+id+'">−</button> '+x.quantity+' <button data-plus="'+id+'">+</button> <button data-remove="'+id+'">حذف</button></p>').join(''):'السلة فارغة';
    $('#cartTotal').textContent=money(rows.reduce((n,[,x])=>n+x.price*x.quantity,0)); save();
  }
  $('#openCart').onclick=()=>{draw();show('cartModal');};
  $('#toCheckout').onclick=()=>{if(!Object.keys(cart).length){alert('السلة فارغة');return;}hide('cartModal');show('checkoutModal');};
  document.querySelectorAll('[data-close]').forEach(b=>b.onclick=()=>hide(b.dataset.close));
  $('#cartItems').addEventListener('click',e=>{const b=e.target.closest('button');if(!b)return;const id=b.dataset.plus||b.dataset.minus||b.dataset.remove;if(!cart[id])return;if(b.dataset.remove)delete cart[id];else if(b.dataset.minus)cart[id].quantity--;else cart[id].quantity++;if(cart[id]&&cart[id].quantity<1)delete cart[id];draw();});
  $('#checkout').addEventListener('submit',async e=>{
    e.preventDefault();const btn=$('#submitOrder'),msg=$('#checkoutMsg');btn.disabled=true;msg.textContent='جارٍ إرسال الطلب…';
    try {
      const fields=Object.fromEntries(new FormData(e.currentTarget).entries());
      const {data,error}=await db.functions.invoke('create-customer-order',{body:{...fields,items:Object.entries(cart).map(([product_id,x])=>({product_id,quantity:x.quantity}))}});
      if(error)throw error;if(data.error)throw new Error(data.error);
      cart={};draw();e.currentTarget.reset();msg.textContent='تم تسجيل الطلب رقم #'+data.order.order_number+'. '+data.message;
      setTimeout(()=>{hide('checkoutModal');alert('تم تسجيل طلبك بنجاح. رقم الطلب: #'+data.order.order_number);},500);
    } catch(err){msg.textContent=err.message||'تعذر إرسال الطلب. حاول مرة أخرى.';}
    finally{btn.disabled=false;}
  });
  save();
})();