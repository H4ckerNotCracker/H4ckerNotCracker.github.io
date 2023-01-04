{% if page.current && page.total %}
    <nav id="pagination" class="blog-pagination">
            {{ 
                paginator({
                    prev_text: "<",
                    next_text: ">", 
                    mid_size: 1
                }) 
            }}
    </nav>
{% endif %}